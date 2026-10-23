#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Raspa rule34.xxx por la web HTML (fallback cuando el API está caído).

Usa las cookies del navegador (Brave por defecto) y escribe en la MISMA base
de datos sqlite que usa gallery-dl (tabla 'archive'), así lo descargado por
aquí no se vuelve a bajar con el modo API y viceversa.

Dos cosas que rule34.xxx/Cloudflare|Exigen:

* Cloudflare pone un "managed challenge" a las peticiones que no parecen venir
  de un navegador (curl/requests siempre caen), por eso se usa curl_cffi, que
  imita el TLS de Chrome. Si curl_cffi no está, se cae a requests (y entonces
  es normal que Cloudflare bloquee).
* El sitio limita las peticiones por conexión: a partir de ~40 pide esperar
  (429). Cuando pasa, se espera el 'Retry-After' y se abre una conexión nueva.

El listado ya trae los tags de cada post (en el atributo 'alt' de la
miniatura), así que los vetados se descartan sin pedir la página del post.

Uso: r34html.py [-d carpeta] [-n cantidad] [-p páginas] [-t umbral] [-v] <url|tags>
"""
import argparse
import os
import re
import sqlite3
import sys
import time
import urllib.parse

import requests

try:
    from curl_cffi import requests as crequests
except ImportError:
    crequests = None

SLEEP = 2.0  # intervalo mínimo entre peticiones (segundos)
UA = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) "
      "Chrome/140.0.0.0 Safari/537.36")
DOMAIN = "rule34.xxx"

RE_THUMB = re.compile(r'<a id="p(\d+)"[^>]*>\s*(<img[^>]*>)')
RE_SRC = re.compile(r'\bsrc="([^"]+)"')
RE_ALT = re.compile(r'\salt="([^"]*)"')
RE_CLASS = re.compile(r'\bclass="([^"]*)"')
RE_VIDEO = re.compile(r'<video[^>]*>\s*<source[^>]*src="([^"]+)"')
RE_ORIGINAL = re.compile(
    r'<a[^>]+href="([^"]+)"[^>]*>\s*Original image\s*</a>')
RE_IMAGE = re.compile(r'<img[^>]*\bsrc="([^"]+)"[^>]*\bid="image"')
RE_IMAGE_ALT = re.compile(r'<img[^>]*\bid="image"[^>]*\bsrc="([^"]+)"')
RE_TAGLIST = re.compile(
    r'<ul[^>]*\bid="tag-(?:sidebar|list)"[^>]*>(.*?)</ul>', re.S)
RE_TAG = re.compile(r'[?;&]tags=([^&"\']+)')
EXTS_VIDEO = ("webm", "mp4")


def normalize_tag(tag):
    """rule34 usa guiones bajos; la web los muestra como espacios."""
    return urllib.parse.unquote_plus(tag).strip().lower().replace(" ", "_")


def load_blacklist(path):
    """Tags vetados: una por línea, comentarios con '#'."""
    tags = set()
    if path:
        with open(path, encoding="utf-8") as fp:
            for line in fp:
                line = line.strip()
                if line and not line.startswith("#"):
                    tags.add(normalize_tag(line))
    return tags


def get_post_tags(html):
    """Tags de un post a partir de su página (contenedor tag-sidebar)."""
    match = RE_TAGLIST.search(html)
    if not match:
        return set()
    tags = set()
    for tag in RE_TAG.findall(match.group(1)):
        tag = normalize_tag(tag)
        if tag:
            tags.add(tag)
    return tags


def browser_cookies(browser, domain=DOMAIN):
    """Cookies del navegador para el dominio de rule34."""
    from gallery_dl import cookies as gdl_cookies
    found = []
    for cookie in gdl_cookies.load_cookies((browser,)):
        host = (cookie.domain or "").lstrip(".")
        if host == domain or host.endswith("." + domain):
            found.append(cookie)
    return found


def load_session(browser):
    """Sesión con las cookies del navegador (curl_cffi imita a Chrome)."""
    cookies = browser_cookies(browser)

    if crequests is not None:
        session = crequests.Session(impersonate="chrome")
        for cookie in cookies:
            session.cookies.set(cookie.name, cookie.value,
                                domain=cookie.domain, path=cookie.path)
        return session

    session = requests.Session()
    jar = requests.cookies.RequestsCookieJar()
    for cookie in cookies:
        jar.set_cookie(cookie)
    session.cookies = jar
    session.headers["User-Agent"] = UA
    return session


class Client:
    """Peticiones con reintentos: 429 -> esperar y abrir conexión nueva."""

    def __init__(self, browser):
        self.browser = browser
        self.session = load_session(browser)

    def get(self, url, **kwargs):
        resp = None
        for attempt in range(4):
            resp = self.session.get(url, **kwargs)
            if resp.status_code != 429:
                return resp
            try:
                wait = int(resp.headers.get("retry-after") or 15)
            except (TypeError, ValueError):
                wait = 15
            print(f"[aviso] rule34XXX pide menos peticiones (429), "
                  f"espero {wait}s", flush=True)
            time.sleep(wait + 1)
            self.session = load_session(self.browser)  # conexión nueva
        return resp


def is_challenge(resp, body):
    """Cloudflare pide verificación (managed challenge) o CAPTCHA propio."""
    return (resp.status_code == 403 or
            "captcha-box" in body or
            "CAPTCHA" in body or
            resp.headers.get("cf-mitigated") == "challenge")


def fetch(client, url, sleep):
    """GET comprobando mantenimiento, CAPTCHA y challenge de Cloudflare."""
    for attempt in range(3):
        resp = client.get(url, timeout=60)
        time.sleep(sleep)
        body = resp.text if resp.status_code == 200 else ""

        if "Temporarily down" in body:
            sys.exit("[error] rule34.xxx está en mantenimiento "
                     "('temporarily down'). Prueba más tarde.")
        if is_challenge(resp, body):
            if attempt < 2:
                wait = 30 * (attempt + 1)
                print(f"[aviso] Cloudflare pide verificación, reintento "
                      f"en {wait}s ({attempt + 1}/3)", flush=True)
                time.sleep(wait)
                continue
            sys.exit("[error] Cloudflare pide verificación para esta "
                     "conexión.\n"
                     "         Abre https://rule34.xxx en Brave, espera a "
                     "que cargue del todo y vuelve a intentarlo.")
        if resp.status_code != 200:
            sys.exit(f"[error] HTTP {resp.status_code} para {url}")
        return body
    return ""


def archive_connect(path):
    """Misma base de datos que gallery-dl (--download-archive)."""
    con = sqlite3.connect(path, timeout=60)
    con.isolation_level = None
    con.execute("CREATE TABLE IF NOT EXISTS archive "
                "(entry TEXT PRIMARY KEY) WITHOUT ROWID")
    return con


def get_file_url(html, root):
    """URL del archivo original en la página de un post."""
    match = (RE_VIDEO.search(html) or
             RE_ORIGINAL.search(html) or
             RE_IMAGE.search(html) or
             RE_IMAGE_ALT.search(html))
    if not match:
        return None
    url = match.group(1)
    if url.startswith("//"):
        url = "https:" + url
    elif url.startswith("/"):
        url = root.rstrip("/") + url
    return url


def download(client, url, path):
    tmp = path + ".part"
    resp = client.get(url, stream=True, timeout=120)
    try:
        resp.raise_for_status()
        with open(tmp, "wb") as file:
            for chunk in resp.iter_content(1 << 16):
                file.write(chunk)
    finally:
        try:
            resp.close()
        except Exception:
            pass
    os.replace(tmp, path)


def parse_listing(html):
    """Posts del listado: (id, url miniatura, tags, es_video)."""
    posts = []
    for pid, img in RE_THUMB.findall(html):
        src = RE_SRC.search(img)
        alt = RE_ALT.search(img)
        cls = RE_CLASS.search(img)
        tags = set()
        if alt:
            tags = {normalize_tag(t) for t in alt.group(1).split() if t}
        video = bool(cls and "webm-thumb" in cls.group(1))
        posts.append((pid, src.group(1) if src else "", tags, video))
    return posts


def main():
    ap = argparse.ArgumentParser(
        description="Raspa un booru gelbooru-v02 por la web HTML")
    ap.add_argument("target", help="URL de búsqueda o tags sueltos")
    ap.add_argument("-d", "--dest", required=True)
    ap.add_argument("-n", "--limit", type=int, default=0,
                    help="máximo de imágenes a descargar (0 = sin límite)")
    ap.add_argument("-p", "--pages", type=int, default=0,
                    help="máximo de páginas a recorrer (0 = sin límite)")
    ap.add_argument("-t", "--threshold", type=int, default=10,
                    help="parar tras N seguidas ya descargadas (0 = off)")
    ap.add_argument("-v", "--videos", action="store_true",
                    help="descargar también webm/mp4")
    ap.add_argument("-b", "--blacklist", metavar="FICHERO",
                    help="fichero de tags vetados (una tag por línea)")
    ap.add_argument("--root", default="https://rule34.xxx")
    ap.add_argument("--browser", default="brave")
    ap.add_argument("--sleep", type=float, default=SLEEP)
    args = ap.parse_args()

    # --- tags / post individual a partir del argumento ---
    post_id = None
    if "://" in args.target:
        query = urllib.parse.parse_qs(
            urllib.parse.urlparse(args.target).query)
        tags = urllib.parse.unquote_plus(query.get("tags", [""])[0])
        if query.get("s") == ["view"]:
            post_id = query.get("id", [None])[0]
            if not post_id:
                sys.exit("[error] URL de post sin id")
    else:
        tags = args.target.replace("+", " ").strip()

    if not tags and not post_id:
        sys.exit("[error] faltan tags o una URL")

    category = urllib.parse.urlparse(args.root).hostname.split(".")[0]
    os.makedirs(args.dest, exist_ok=True)
    con = archive_connect(os.path.join(args.dest, ".archive.sqlite3"))
    client = Client(args.browser)
    blacklist = load_blacklist(args.blacklist)

    downloaded = 0
    consecutivos = 0  # seguidas ya en la base de datos
    vistos = set()    # ids vistos en esta ejecución (protección anti-bucle)
    pagina = 0
    pid = 0           # desplazamiento de posts en el listado

    print(f"Raspando {args.root} tags='{tags or 'post ' + post_id}' "
          f"-> {args.dest}", flush=True)
    if crequests is None:
        print("[aviso] curl_cffi no está instalado: Cloudflare puede "
              "bloquear las peticiones", flush=True)

    while True:
        if args.pages and pagina >= args.pages:
            print(f"Límite de {args.pages} páginas alcanzado", flush=True)
            break

        # --- obtener posts de la página de listado ---
        if post_id:
            if pagina > 0:
                break
            listing = [(post_id, "", set(), False)]
        else:
            url = ("{}/index.php?page=post&s=list&tags={}&pid={}".format(
                args.root, urllib.parse.quote(tags), pid))
            html = fetch(client, url, args.sleep)
            listing = parse_listing(html)
            if not listing:
                print(f"Fin de los resultados (página {pagina})",
                      flush=True)
                break
            pid += len(listing)  # 'pid' es el desplazamiento en posts

        nuevos = [p for p in listing if p[0] not in vistos]
        if not nuevos:
            print("Fin de los resultados (la página se repetía)", flush=True)
            break
        vistos.update(p[0] for p in nuevos)

        # --- procesar cada post ---
        for post, thumb, post_tags, is_video in nuevos:
            # misma clave que gallery-dl: categoría + "t_{tags}_{id}"
            key = f"{category}t_{tags}_{post}"
            if con.execute("SELECT 1 FROM archive WHERE entry=? LIMIT 1",
                           (key,)).fetchone():
                consecutivos += 1
                if args.threshold and consecutivos >= args.threshold:
                    print(f"Paro: {consecutivos} seguidas ya estaban "
                          "en la base de datos", flush=True)
                    return
                continue

            # el listado ya trae los tags: se descartan los vetados sin
            # pedir la página del post
            if blacklist and post_tags:
                bad = post_tags & blacklist
                if bad:
                    print(f"Post {post}: tags vetados "
                          f"({', '.join(sorted(bad))})", flush=True)
                    continue  # neutral: no cuenta como ya descargado

            if is_video and not args.videos:
                print(f"Post {post}: vídeo omitido, usa -v", flush=True)
                continue  # neutral: no cuenta como ya descargado

            html = fetch(client, "{}/index.php?page=post&s=view&id={}"
                         .format(args.root, post), args.sleep)

            if blacklist and not post_tags:
                bad = get_post_tags(html) & blacklist
                if bad:
                    print(f"Post {post}: tags vetados "
                          f"({', '.join(sorted(bad))})", flush=True)
                    continue

            file_url = get_file_url(html, args.root)
            if not file_url:
                print(f"[aviso] No encontré el archivo del post {post}",
                      flush=True)
                continue

            basename = os.path.basename(
                urllib.parse.urlparse(file_url).path)
            stem, _, ext = basename.rpartition(".")
            ext = ext.lower()
            if ext in EXTS_VIDEO and not args.videos:
                print(f"Post {post}: vídeo (.{ext}) omitido, usa -v",
                      flush=True)
                continue  # neutral: no cuenta como ya descargado

            name = f"{category}_{post}_{stem}.{ext or 'jpg'}"
            path = os.path.join(args.dest, name)
            if not os.path.exists(path):
                try:
                    download(client, file_url, path)
                except Exception as exc:
                    print(f"[aviso] Falló la descarga del post {post}: "
                          f"{exc}", flush=True)
                    continue
            con.execute("INSERT OR IGNORE INTO archive (entry) VALUES (?)",
                        (key,))
            consecutivos = 0
            downloaded += 1
            print(f"Post {post}: {name}", flush=True)

            if args.limit and downloaded >= args.limit:
                print(f"Límite de {args.limit} imágenes alcanzado",
                      flush=True)
                return

        pagina += 1

    total = len([f for f in os.listdir(args.dest)
                 if not f.startswith(".")])
    print(f"Listo: {downloaded} descargadas esta vez, "
          f"{total} archivos en {args.dest}", flush=True)


if __name__ == "__main__":
    main()
