"""Writes arke_world's shared music fixtures (SPEC-058 R-68 – R-70), which ArkeStudio's contracts read too.

    python packages/arke_world/tool/make_music_fixtures.py packages/arke_world/test/fixtures/music

A "music" case is a music document read against assets.json; a "manifest" case is a world.json, a
production package (schema 5) or an older package that names music it cannot.
"""
import copy
import json
import os
import sys

d = sys.argv[1]
os.makedirs(d, exist_ok=True)


def a(path, mt):
    return {'path': path, 'mediaType': mt, 'byteLength': 1, 'sha256': '0' * 64}


ALBUM = 'songs-of-the-drowned-quarter'
assets = {
    'music': a(f'{ALBUM}/music.json', 'application/vnd.arke.music+json'),
    'cover': a(f'{ALBUM}/cover.jpg', 'image/jpeg'),
    'a-drowned-verse': a(f'{ALBUM}/tracks/the-drowned-verse.m4a', 'audio/mp4'),
    'a-slack-water': a(f'{ALBUM}/tracks/slack-water.m4a', 'audio/mp4'),
    'a-saltmouth-bells': a(f'{ALBUM}/tracks/saltmouth-bells.m4a', 'audio/mp4'),
}
# An album: tracks in order, each with its audio and length in milliseconds, the words as written with
# the sections the Studio marked, and where in the world it is heard. A Heard in may name a production
# this package does not hold: it is the world's, shown when that production is installed.
album = {
    'format': 'arke-music', 'version': 1, 'kind': 'album',
    'tracks': [
        {'id': 'the-drowned-verse', 'title': 'The Drowned Verse', 'audio': 'a-drowned-verse', 'duration': 238000,
         'lyrics': {'text': 'Under the harbour the old bells turn,\nsalt in the ledger, the lamps that burn.\n\nHold the verse, hold it low,\ndown where the drowned ones go.',
                    'sections': [{'label': 'Intro', 'at': 0}, {'label': 'Verse', 'at': 14000}, {'label': 'Chorus', 'at': 62000}, {'label': 'Outro', 'at': 220000}]},
         'heardIn': [{'production': 'the-ledger-of-nights', 'chapter': 'a-choir-underwater', 'at': 730000}]},
        {'id': 'slack-water', 'title': 'Slack Water', 'audio': 'a-slack-water', 'duration': 185000},
        {'id': 'saltmouth-bells', 'title': 'Saltmouth Bells', 'audio': 'a-saltmouth-bells', 'duration': 222000,
         'heardIn': [{'production': 'the-ledger-of-nights', 'chapter': 'saltmouth-bells', 'at': 41000}]},
    ],
}


def w(name, doc):
    with open(os.path.join(d, name), 'w', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(doc, indent=2, ensure_ascii=False) + '\n')


w('assets.json', assets)
cases = []


def music(name, expect, mutate=None, **extra):
    doc = copy.deepcopy(album)
    if mutate:
        mutate(doc)
    w(name, doc)
    cases.append({'file': name, 'reader': 'music', 'expect': expect, **extra})


def one_track(x):
    x.update(kind='single')
    del x['tracks'][1:]


music('album.json', 'ok', kind='album', tracks=['the-drowned-verse', 'slack-water', 'saltmouth-bells'], sections=4)
music('single.json', 'ok', one_track, kind='single', tracks=['the-drowned-verse'], sections=4)
music('soundtrack.json', 'ok', lambda x: x.update(kind='soundtrack', **{'for': 'the-bell-watch'}), kind='soundtrack', tracks=['the-drowned-verse', 'slack-water', 'saltmouth-bells'])
music('metadata.json', 'ok', lambda x: (x.update(metadata={'studio': '0.5.70'}), x['tracks'][0].update(metadata={'take': 'take 2 of 3'})))
music('single-two-tracks.json', 'notAPackage', lambda x: (x.update(kind='single'), x['tracks'].pop()))
music('soundtrack-without-for.json', 'notAPackage', lambda x: x.update(kind='soundtrack'))
music('album-with-for.json', 'notAPackage', lambda x: x.update(**{'for': 'the-bell-watch'}))
music('section-past-end.json', 'notAPackage', lambda x: x['tracks'][0]['lyrics']['sections'].append({'label': 'Coda', 'at': 238000}))
music('sections-out-of-order.json', 'notAPackage', lambda x: x['tracks'][0]['lyrics']['sections'][2].update(at=10000))
music('audio-not-audio.json', 'notAPackage', lambda x: x['tracks'][1].update(audio='cover'))
music('audio-missing.json', 'notAPackage', lambda x: x['tracks'][1].update(audio='a-undersong'))
music('track-repeats.json', 'notAPackage', lambda x: x['tracks'][2].update(id='slack-water'))
music('track-too-long.json', 'notAPackage', lambda x: x['tracks'][1].update(duration=15 * 60000 + 1))
music('no-tracks.json', 'notAPackage', lambda x: x.update(tracks=[]))
music('kind-unknown.json', 'notAPackage', lambda x: x.update(kind='ep'))
music('heard-in-at.json', 'notAPackage', lambda x: x['tracks'][2]['heardIn'][0].update(at=-1))
music('unknown-key.json', 'newerArke', lambda x: x['tracks'][0].update(bpm=72))
music('newer-version.json', 'newerArke', lambda x: x.update(version=2))
music('requires.json', 'newerArke', lambda x: x.update(requires=['music-v2']))


# A production package (schema 5): one production published alone, beside the world's edition. It names
# the world but carries no guide, key art or part; a music production names its document in place of a
# book or a narration, and its square cover as its picture.
package = {
    'format': 'arke-world-package', 'schemaVersion': 5, 'id': 'the-undersong', 'edition': '2026-10-24', 'name': 'The Undersong',
    'logline': 'A drowned god still sings beneath the harbour of Saltmouth.', 'alone': True,
    'productions': [{'id': ALBUM, 'title': 'Songs of the Drowned Quarter', 'picture': 'cover', 'music': 'music'}],
    'assets': copy.deepcopy(assets),
}


def manifest(name, expect, mutate=None, **extra):
    doc = copy.deepcopy(package)
    if mutate:
        mutate(doc)
    w(name, doc)
    cases.append({'file': name, 'reader': 'manifest', 'expect': expect, **extra})


def with_asset(x, key, path, mt):
    x['assets'][key] = a(path, mt)


manifest('world-album.json', 'ok', alone=True, music='music')
# A production published alone need not be music: one listening production on its own reads too.
manifest('world-alone-listening.json', 'ok', lambda x: (
    x['productions'][0].pop('music'), x['productions'][0].update(listening='listening'),
    x['assets'].pop('music'), with_asset(x, 'listening', f'{ALBUM}/listening.json', 'application/vnd.arke.listening+json')), alone=True)
manifest('world-music-beside-book.json', 'notAPackage', lambda x: (x['productions'][0].update(book='book'), with_asset(x, 'book', f'{ALBUM}/book.epub', 'application/epub+zip')))
manifest('world-music-wrong-media.json', 'notAPackage', lambda x: x['productions'][0].update(music='cover'))
manifest('world-alone-with-guide.json', 'notAPackage', lambda x: (x.update(guide='guide'), with_asset(x, 'guide', 'guide/guide.json', 'application/vnd.arke.guide+json')))
manifest('world-alone-with-key-art.json', 'notAPackage', lambda x: (x.update(keyArt='key-art'), with_asset(x, 'key-art', 'key-art.jpg', 'image/jpeg')))
manifest('world-alone-with-part.json', 'notAPackage', lambda x: x.update(part={'follows': '2026-10-22', 'fingerprint': 'a' * 64, 'number': 1}))
manifest('world-alone-two-productions.json', 'notAPackage', lambda x: x['productions'].append({'id': 'saltmouth-bells', 'title': 'Saltmouth Bells', 'picture': 'cover', 'music': 'music'}))
manifest('world-schema-5-not-alone.json', 'notAPackage', lambda x: x.pop('alone'))
manifest('world-alone-false.json', 'notAPackage', lambda x: x.update(alone=False))
manifest('world-schema-6.json', 'newerArke', lambda x: x.update(schemaVersion=6))
# Music and `alone` came with schema 5: an older package naming either was made by a newer Arke.
manifest('world-music-in-schema-3.json', 'newerArke', lambda x: (x.update(schemaVersion=3), x.pop('alone')))
manifest('world-alone-in-schema-4.json', 'newerArke', lambda x: x.update(schemaVersion=4, part={'follows': '2026-10-22', 'fingerprint': 'a' * 64, 'number': 1}))

w('cases.json', {
    'note': 'SPEC-058 R-68 – R-70: the music cases both readers run, Arke Player arke_world (Dart) and ArkeStudio contracts (TypeScript). '
            'A "music" case is a music document read against assets.json: "kind" and "tracks" list what an ok case reads, '
            '"sections" the first track\'s sections. A "manifest" case is a world.json: "alone" and "music" are what an ok one names.',
    'cases': cases,
})
print(len(cases), 'cases')
