"""Writes arke_world's shared listening fixtures (SPEC-058 R-16), which ArkeStudio's contracts read too.

    python packages/arke_world/tool/make_listening_fixtures.py packages/arke_world/test/fixtures/listening
"""
import copy
import json
import os
import sys

d = sys.argv[1]
os.makedirs(d, exist_ok=True)


def a(path, mt):
    return {'path': path, 'mediaType': mt, 'byteLength': 1, 'sha256': '0' * 64}


assets = {
    'cover': a('ledger/cover.jpg', 'image/jpeg'),
    'a01': a('ledger/audio/ch01.m4a', 'audio/mp4'),
    'a02': a('ledger/audio/ch02.m4a', 'audio/mp4'),
    'p001': a('ledger/pictures/p001.jpg', 'image/jpeg'),
    'p002': a('ledger/pictures/p002.jpg', 'image/jpeg'),
    'p003': a('ledger/pictures/p003.png', 'image/png'),
    'm001': a('ledger/motion/m001.mp4', 'video/mp4'),
}
valid = {
    'format': 'arke-listening', 'version': 1, 'timescale': 1000,
    'title': 'The Ledger of Nights', 'cover': 'cover',
    'chapters': [
        {'id': 'neap', 'order': 1, 'title': 'Neap', 'duration': 60000, 'audio': 'a01', 'book': 'OEBPS/chapter-1.xhtml', 'opening': 'p001',
         'pictures': [
             {'at': 5000, 'picture': 'p001', 'focus': {'x': 0.42, 'y': 0.31}},
             {'at': 20000, 'hold': 15000, 'picture': 'p002', 'motion': {'video': 'm001', 'behavior': 'repeat'}},
             {'at': 40000, 'picture': 'p003'},
         ],
         'phrases': [
             {'at': 1200, 'end': 5400, 'text': 'The tide-clock keeps the drowned god’s hours.',
              'words': [{'at': 1200, 'end': 1480, 'text': 'The'}, {'at': 1480, 'end': 2300, 'text': 'tide-clock'}]},
             {'at': 5400, 'end': 9000, 'text': 'Nobody in Saltmouth winds it.'},
         ]},
        {'id': 'the-rail-book', 'order': 2, 'title': 'The rail book', 'duration': 30000, 'audio': 'a02', 'pictures': [{'at': 0, 'picture': 'p002'}]},
    ],
}


def w(name, doc):
    with open(os.path.join(d, name), 'w', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(doc, indent=2, ensure_ascii=False) + '\n')


w('assets.json', assets)
w('valid.json', valid)
cases = [{'file': 'valid.json', 'expect': 'ok', 'at': [
    {'chapter': 'neap', 'ms': 0, 'picture': None, 'phrase': None},
    {'chapter': 'neap', 'ms': 1300, 'picture': None, 'phrase': 0},
    {'chapter': 'neap', 'ms': 5000, 'picture': 'p001', 'phrase': 0},
    {'chapter': 'neap', 'ms': 5400, 'picture': 'p001', 'phrase': 1},
    {'chapter': 'neap', 'ms': 19999, 'picture': 'p001', 'phrase': None},
    {'chapter': 'neap', 'ms': 34999, 'picture': 'p002', 'phrase': None},
    {'chapter': 'neap', 'ms': 35000, 'picture': None, 'phrase': None},
    {'chapter': 'neap', 'ms': 59999, 'picture': 'p003', 'phrase': None},
    {'chapter': 'the-rail-book', 'ms': 100, 'picture': 'p002', 'phrase': None},
]}]


def case(name, expect, mutate):
    doc = copy.deepcopy(valid)
    mutate(doc)
    w(name, doc)
    cases.append({'file': name, 'expect': expect})


case('metadata.json', 'ok', lambda x: (x.update(metadata={'studio': '0.5.62'}), x['chapters'][0].update(metadata={'take': 'kept'})))
case('newer-version.json', 'newerArke', lambda x: x.update(version=2))
case('requires.json', 'newerArke', lambda x: x.update(requires=['motion-v2']))
case('unknown-key.json', 'newerArke', lambda x: x['chapters'][0].update(effects=[]))
case('missing-asset.json', 'notAPackage', lambda x: x['chapters'][0]['pictures'][0].update(picture='p999'))
case('wrong-media.json', 'notAPackage', lambda x: x['chapters'][1].update(audio='p002'))
case('out-of-order.json', 'notAPackage', lambda x: x['chapters'][0]['pictures'][2].update(at=10000))
case('overlap.json', 'notAPackage', lambda x: x['chapters'][0]['pictures'][1].update(hold=25000))
case('word-outside.json', 'notAPackage', lambda x: x['chapters'][0]['phrases'][0]['words'][1].update(end=6000))
# Phrases follow one another: one that starts before the last has ended could never be shown.
case('phrase-overlap.json', 'notAPackage', lambda x: x['chapters'][0]['phrases'][1].update(at=5000))
case('duplicate-order.json', 'notAPackage', lambda x: x['chapters'][1].update(order=1))
case('picture-after-end.json', 'notAPackage', lambda x: x['chapters'][1]['pictures'][0].update(at=30000))
w('cases.json', {
    'note': 'SPEC-058 R-16: the listening-document cases both readers run, Arke Player arke_world (Dart) and ArkeStudio contracts (TypeScript). '
            'Each file is read against assets.json; "at" lists the picture (asset id) and phrase (index) showing at a time on a chapter clock.',
    'cases': cases,
})
print(len(cases), 'cases')
