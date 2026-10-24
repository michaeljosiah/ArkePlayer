"""Writes arke_world's shared part fixtures (SPEC-058 R-46), which ArkeStudio's contracts read too.

    python packages/arke_world/tool/make_part_fixtures.py packages/arke_world/test/fixtures/part

Every case is a `world.json`, read by each reader's world manifest reader.
"""
import copy
import json
import os
import sys

d = sys.argv[1]
os.makedirs(d, exist_ok=True)


def a(path, mt):
    return {'path': path, 'mediaType': mt, 'byteLength': 1, 'sha256': '0' * 64}


LEDGER = 'the-ledger-of-nights'
# A part: the chapters read whole since the edition it follows, and nothing released before. It names
# that edition by label and fingerprint, counts the parts after it from 1, and carries the author's
# schedule when there is one.
valid = {
    'format': 'arke-world-package', 'schemaVersion': 4, 'id': 'the-undersong', 'edition': '2026-10-30', 'name': 'The Undersong',
    'logline': 'A drowned god still sings beneath the harbour of Saltmouth.',
    'part': {'follows': '2026-10-22', 'fingerprint': 'a' * 64, 'number': 1, 'schedule': {'day': 'friday', 'next': '2026-11-06'}},
    'productions': [{'id': LEDGER, 'title': 'The Ledger of Nights', 'listening': 'listening', 'book': 'book'}],
    'assets': {
        'listening': a(f'{LEDGER}/listening.json', 'application/vnd.arke.listening+json'),
        'book': a(f'{LEDGER}/book.epub', 'application/epub+zip'),
    },
}


def w(name, doc):
    with open(os.path.join(d, name), 'w', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(doc, indent=2, ensure_ascii=False) + '\n')


cases = []


def case(name, expect, mutate=None, **extra):
    doc = copy.deepcopy(valid)
    if mutate:
        mutate(doc)
    w(name, doc)
    cases.append({'file': name, 'reader': 'manifest', 'expect': expect, **extra})


case('part.json', 'ok', part={'follows': '2026-10-22', 'number': 1, 'day': 'friday', 'next': '2026-11-06'})
case('part-no-schedule.json', 'ok', lambda x: x['part'].pop('schedule'), part={'follows': '2026-10-22', 'number': 1})
case('part-daily.json', 'ok', lambda x: x['part'].update(number=2, schedule={'day': 'daily'}), part={'follows': '2026-10-22', 'number': 2, 'day': 'daily'})
case('part-book-alone.json', 'ok', lambda x: (x['productions'][0].pop('listening'), x['assets'].pop('listening')))
case('part-missing.json', 'notAPackage', lambda x: x.pop('part'))
case('part-in-schema-3.json', 'newerArke', lambda x: x.update(schemaVersion=3))
case('schema-5.json', 'newerArke', lambda x: x.update(schemaVersion=5))
# A part carries no guide: a guide reaches phones alone, or in the next edition.
case('part-with-guide.json', 'notAPackage', lambda x: (x.update(guide='guide'), x['assets'].update(guide=a('guide/guide.json', 'application/vnd.arke.guide+json'))))
case('part-two-productions.json', 'notAPackage', lambda x: (x['productions'].append({'id': 'saltmouth-tales', 'title': 'Saltmouth Tales', 'book': 'book-2'}), x['assets'].update({'book-2': a('saltmouth-tales/book.epub', 'application/epub+zip')})))
case('part-no-production.json', 'notAPackage', lambda x: x.update(productions=[]))
# A single narration file cannot be added to: a part's chapters come as a listening document.
case('part-narration.json', 'notAPackage', lambda x: (x['productions'][0].pop('listening'), x['productions'][0].update(narration='narration'), x['assets'].pop('listening'), x['assets'].update(narration=a(f'{LEDGER}/narration.m4b', 'audio/mp4'))))
case('part-fingerprint.json', 'notAPackage', lambda x: x['part'].update(fingerprint='not-a-digest'))
case('part-number.json', 'notAPackage', lambda x: x['part'].update(number=0))
case('part-follows.json', 'notAPackage', lambda x: x['part'].update(follows='  '))
case('part-day.json', 'notAPackage', lambda x: x['part']['schedule'].update(day='someday'))
case('part-next.json', 'notAPackage', lambda x: x['part']['schedule'].update(next='6 Nov'))
case('part-unknown-key.json', 'newerArke', lambda x: x['part'].update(title='Chapter 24'))
case('part-schedule-unknown-key.json', 'newerArke', lambda x: x['part']['schedule'].update(time='09:00'))

w('cases.json', {
    'note': 'SPEC-058 R-46: the part cases both readers run, Arke Player arke_world (Dart) and ArkeStudio contracts (TypeScript). '
            'Each file is a world.json. "part" lists what an ok case reads: follows, number, and the schedule\'s day and next.',
    'days': ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday', 'daily'],
    'cases': cases,
})
print(len(cases), 'cases')
