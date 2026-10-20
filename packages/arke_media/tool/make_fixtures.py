"""Makes arke_media's test fixtures. Needs ffmpeg on PATH and Pillow. Every file is a few KB.

    python packages/arke_media/tool/make_fixtures.py
"""
import io
import os
import subprocess
import tempfile
import zipfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'test', 'fixtures')
os.makedirs(OUT, exist_ok=True)


def run(*args):
    subprocess.run(['ffmpeg', '-v', 'error', '-y', *args], check=True)


with tempfile.TemporaryDirectory() as tmp:
    cover = os.path.join(tmp, 'cover.jpg')
    Image.new('RGB', (32, 32), (40, 70, 110)).save(cover, quality=70)

    # Three chapters over six seconds, as an audiobook tool writes them.
    meta = os.path.join(tmp, 'meta.txt')
    with open(meta, 'w', encoding='utf-8') as f:
        f.write(';FFMETADATA1\ntitle=Tidewater Sessions\nartist=Amaal Reyes\nalbum=Tidewater Sessions\n')
        for i, (start, end, title) in enumerate([(0, 2000, 'The Weigh House'), (2000, 4000, 'The Weir'), (4000, 6000, 'The Tenth Key')]):
            f.write(f'[CHAPTER]\nTIMEBASE=1/1000\nSTART={start}\nEND={end}\ntitle={title}\n')

    run('-f', 'lavfi', '-i', 'sine=frequency=440:duration=6', '-i', meta, '-i', cover,
        '-map', '0:a', '-map', '2:v', '-map_metadata', '1', '-map_chapters', '1',
        '-c:a', 'aac', '-b:a', '16k', '-ac', '1', '-c:v', 'mjpeg', '-disposition:v', 'attached_pic',
        '-f', 'mp4', os.path.join(OUT, 'chapters.m4b'))

    run('-f', 'lavfi', '-i', 'sine=frequency=330:duration=6', '-i', meta, '-i', cover,
        '-map', '0:a', '-map', '2:v', '-map_metadata', '1', '-map_chapters', '1',
        '-c:a', 'libmp3lame', '-b:a', '32k', '-ac', '1', '-c:v', 'copy', '-id3v2_version', '3',
        os.path.join(OUT, 'tagged.mp3'))

    run('-f', 'lavfi', '-i', 'testsrc=size=64x36:rate=10:duration=2', '-metadata', 'title=Lighthouse reel',
        '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-f', 'mp4', os.path.join(OUT, 'reel.mp4'))
    run('-f', 'lavfi', '-i', 'testsrc=size=64x36:rate=10:duration=1', '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
        '-f', 'mov', os.path.join(OUT, 'clip.mov'))

    cover_bytes = open(cover, 'rb').read()


def epub(name, extra=None):
    with zipfile.ZipFile(os.path.join(OUT, name), 'w') as z:
        # The mimetype is first and stored, as OCF requires; probeFile relies on it.
        z.writestr(zipfile.ZipInfo('mimetype'), 'application/epub+zip', compress_type=zipfile.ZIP_STORED)
        z.writestr('META-INF/container.xml', '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>')
        z.writestr('OEBPS/content.opf', '<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">urn:uuid:00000000-0000-4000-8000-000000000000</dc:identifier><dc:title>The Salt Almanac</dc:title><dc:creator>Ines Varga</dc:creator><dc:language>en</dc:language></metadata><manifest><item id="c1" href="text/one.xhtml" media-type="application/xhtml+xml"/><item id="cover" href="images/cover.jpg" media-type="image/jpeg" properties="cover-image"/></manifest><spine><itemref idref="c1"/></spine></package>')
        z.writestr('OEBPS/text/one.xhtml', '<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml"><head><title>One</title></head><body><h1>The Tenth Key</h1><p>The key had no teeth.</p></body></html>')
        z.writestr('OEBPS/images/cover.jpg', cover_bytes)
        for path, text in (extra or {}).items():
            z.writestr(path, text)


epub('book.epub')
epub('fonts-only.epub', {'META-INF/encryption.xml': '<encryption><EncryptedData><EncryptionMethod Algorithm="http://www.idpf.org/2008/embedding"/></EncryptedData></encryption>'})
epub('protected.epub', {'META-INF/rights.xml': '<rights/>'})

for name in sorted(os.listdir(OUT)):
    print(f'{os.path.getsize(os.path.join(OUT, name)):>7}  {name}')
