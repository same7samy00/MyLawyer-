#!/usr/bin/env python3
# Fills the map cache for populated areas, slowly enough to leave the server free
import math, ssl, sys, time, urllib.request
from concurrent.futures import ThreadPoolExecutor

AREAS = [
    ('egypt', 21.8, 24.5, 31.9, 37.1, 5, 10),
    ('nile_valley', 24.0, 30.5, 30.0, 33.2, 11, 13),
    ('red_sea_sinai', 26.8, 32.2, 31.4, 34.6, 11, 13),
    ('north_coast', 30.7, 27.0, 31.5, 29.9, 11, 13),
    ('delta_canal', 30.2, 29.8, 31.7, 32.7, 11, 15),
    ('greater_cairo', 29.75, 30.85, 30.35, 31.75, 11, 15),
    ('alexandria', 30.95, 29.7, 31.35, 30.15, 11, 15),
]


def tile(lat, lon, z):
    n = 2 ** z
    return int((lon + 180) / 360 * n), int((1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n)


todo = set()
for _, south, west, north, east, z0, z1 in AREAS:
    for z in range(z0, z1 + 1):
        x0, y0 = tile(north, west, z)
        x1, y1 = tile(south, east, z)
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                todo.add((z, x, y))

tiles = sorted(todo)
print('tiles', len(tiles), flush=True)
if len(sys.argv) > 1 and sys.argv[1] == 'count':
    sys.exit(0)

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE


def fetch(t):
    z, x, y = t
    req = urllib.request.Request(f'https://127.0.0.1/map/v1/{z}/{x}/{y}.webp', headers={'Host': 'my-lawyer.online'})
    with urllib.request.urlopen(req, context=ctx, timeout=60) as response:
        response.read()


fails = 0
done = 0
started = time.time()
with ThreadPoolExecutor(2) as pool:
    for i in range(0, len(tiles), 40):
        batch = tiles[i:i + 40]
        for future in [pool.submit(fetch, t) for t in batch]:
            try:
                future.result()
            except Exception:
                fails += 1
        done += len(batch)
        if done % 2000 < 40:
            print(done, 'fails', fails, int(time.time() - started), 's', flush=True)
print('DONE', done, 'fails', fails, int(time.time() - started), 's', flush=True)
