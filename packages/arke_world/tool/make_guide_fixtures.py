"""Writes arke_world's shared guide fixtures (SPEC-059 R-16), which ArkeStudio's contracts read too.

    python packages/arke_world/tool/make_guide_fixtures.py packages/arke_world/test/fixtures/guide
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
    'guide': a('guide/guide.json', 'application/vnd.arke.guide+json'),
    'g-maren': a('guide/maren-kest.jpg', 'image/jpeg'),
    'g-bray': a('guide/bray-half-hitch.png', 'image/png'),
    'g-vigil': a('guide/the-vigil.jpg', 'image/jpeg'),
    'g-maren-voice': a('guide/maren-kest.m4a', 'audio/mp4'),
    # Teasers' own files (revision 5): a picture fitted for a phone, a clip's narration and its loop.
    't-bells': a('guide/teasers/saltmouth-bells.jpg', 'image/jpeg'),
    't-bells-audio': a('guide/teasers/saltmouth-bells.m4a', 'audio/mp4'),
    't-bells-loop': a('guide/teasers/saltmouth-bells.mp4', 'video/mp4'),
    't-weir': a('guide/teasers/the-weir.jpg', 'image/jpeg'),
}
LEDGER = 'the-ledger-of-nights'
SIX = {'production': LEDGER, 'chapter': 'independent-record'}
valid = {
    'format': 'arke-guide', 'version': 1,
    # What an `after` and a voice line name: a production's chapters in manuscript order, each with
    # the number a reader knows it by, so a guide alone can say After Chapter 6.
    'productions': [
        {'id': LEDGER, 'title': 'The Ledger of Nights', 'chapters': [
            {'id': 'neap', 'number': 1, 'book': 'OEBPS/chapter-1.xhtml'},
            {'id': 'the-rail-book', 'number': 2, 'book': 'OEBPS/chapter-2.xhtml'},
            {'id': 'independent-record', 'number': 6},
        ]},
    ],
    'characters': [
        {'id': 'maren-kest', 'name': 'Maren Kest', 'role': 'Tide-caller', 'portrait': 'g-maren', 'after': None,
         'sections': [
             {'heading': 'Essence', 'text': 'Tide-caller. She hears the verse under the harbour and pulls the water where it needs to go.'},
             {'heading': 'Relationships', 'text': 'Trusts Bray with her life, not her secrets.', 'after': SIX},
         ],
         'voice': {'audio': 'g-maren-voice', 'text': 'I hear it. I always hear it.', 'duration': 8000, 'production': LEDGER, 'chapter': 'the-rail-book'},
         'links': ['bray-half-hitch', 'the-vigil']},
        {'id': 'bray-half-hitch', 'name': 'Bray Half-Hitch', 'role': 'Rigger', 'portrait': 'g-bray',
         'sections': [{'heading': 'Essence', 'text': 'Rigger on the Vigil’s night crew.'}], 'links': ['maren-kest']},
        {'id': 'the-chorister', 'name': 'The Chorister', 'after': SIX, 'sections': [{'heading': 'Essence', 'text': 'Keeper of the drowned verse.'}]},
    ],
    'places': [
        {'id': 'the-vigil', 'name': 'The Vigil', 'role': 'Harbour mouth', 'picture': 'g-vigil',
         'sections': [{'heading': 'Look', 'text': 'A watchtower of black stone at the harbour mouth.'}], 'links': ['maren-kest']},
    ],
    'lore': [
        {'id': 'canon-001', 'kind': 'lore', 'title': 'The Undersong', 'text': 'Beneath the harbour lies a drowned god, and it is still singing.', 'links': ['maren-kest', 'the-vigil']},
        {'id': 'canon-031', 'kind': 'timeline', 'title': 'The drowning of the god', 'text': 'The god went under in the year of the long neap.', 'after': SIX},
    ],
}


def w(name, doc):
    with open(os.path.join(d, name), 'w', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(doc, indent=2, ensure_ascii=False) + '\n')


w('assets.json', assets)
w('valid.json', valid)
cases = [{'file': 'valid.json', 'expect': 'ok',
          'counts': {'characters': 3, 'places': 1, 'lore': 2},
          # The chapter number each `after` resolves to; a section is named by its index.
          'after': [
              {'entry': 'maren-kest', 'number': None},
              {'entry': 'maren-kest', 'section': 1, 'number': 6},
              {'entry': 'the-chorister', 'number': 6},
              {'entry': 'the-vigil', 'section': 0, 'number': None},
              {'entry': 'canon-031', 'number': 6},
          ]}]


def case(name, expect, mutate):
    doc = copy.deepcopy(valid)
    mutate(doc)
    w(name, doc)
    cases.append({'file': name, 'expect': expect})


case('metadata.json', 'ok', lambda x: (x.update(metadata={'studio': '0.5.62'}), x['characters'][0].update(metadata={'sheet': 'kept'})))
case('newer-version.json', 'newerArke', lambda x: x.update(version=3))
case('requires.json', 'newerArke', lambda x: x.update(requires=['guide-v2']))
case('unknown-key.json', 'newerArke', lambda x: x['characters'][0].update(age=31))
case('repeat-id.json', 'notAPackage', lambda x: x['characters'][1].update(id='maren-kest'))
# A link names an entry without its kind, so an id is the guide's, not only its kind's.
case('repeat-id-across.json', 'notAPackage', lambda x: x['places'][0].update(id='bray-half-hitch'))
case('link-to-nothing.json', 'notAPackage', lambda x: x['characters'][1]['links'].append('the-quiet-ward'))
case('after-no-chapter.json', 'notAPackage', lambda x: x['lore'][1].update(after={'production': LEDGER, 'chapter': 'the-tithe'}))
case('after-no-production.json', 'notAPackage', lambda x: x['characters'][2].update(after={'production': 'saltmouth-tales', 'chapter': 'neap'}))
case('empty-section.json', 'notAPackage', lambda x: x['places'][0]['sections'][0].update(text='  '))
case('missing-asset.json', 'notAPackage', lambda x: x['characters'][0].update(portrait='g-perrin'))
case('wrong-media.json', 'notAPackage', lambda x: x['characters'][0]['voice'].update(audio='g-maren'))
case('long-voice.json', 'notAPackage', lambda x: x['characters'][0]['voice'].update(duration=15001))
case('lore-kind.json', 'notAPackage', lambda x: x['lore'][0].update(kind='myth'))
case('chapters-out-of-order.json', 'notAPackage', lambda x: x['productions'][0]['chapters'][2].update(number=2))


# Teasers (SPEC-059 revision 5, R-28, R-29): version 2 of the guide document adds them, at most six in
# the author's order. A character or place names an entry public from the start; a picture or clip
# carries its own files and the chapter it is from, which the Player shows on its card.
ONE = {'production': LEDGER, 'chapter': 'neap'}
teasers = copy.deepcopy(valid)
teasers['version'] = 2
teasers['teasers'] = [
    {'kind': 'character', 'id': 'maren-kest'},
    {'kind': 'clip', 'title': 'Saltmouth bells', 'picture': 't-bells', 'audio': 't-bells-audio', 'duration': 24000, 'motion': 't-bells-loop', **ONE},
    {'kind': 'place', 'id': 'the-vigil'},
    {'kind': 'picture', 'title': 'The weir at low water', 'picture': 't-weir', 'production': LEDGER, 'chapter': 'independent-record'},
]
w('teasers.json', teasers)
cases.append({'file': 'teasers.json', 'expect': 'ok', 'counts': {'characters': 3, 'places': 1, 'lore': 2},
              'teasers': ['character', 'clip', 'place', 'picture']})


def teaser_case(name, expect, mutate):
    doc = copy.deepcopy(teasers)
    mutate(doc)
    w(name, doc)
    cases.append({'file': name, 'expect': expect})


teaser_case('teasers-version-1.json', 'newerArke', lambda x: x.update(version=1))
teaser_case('teaser-seven.json', 'notAPackage', lambda x: x['teasers'].extend([{'kind': 'character', 'id': 'bray-half-hitch'}, {'kind': 'picture', 'title': 'Bells', 'picture': 't-bells', **ONE}, {'kind': 'picture', 'title': 'Weir', 'picture': 't-weir', **ONE}]))
teaser_case('teaser-repeat.json', 'notAPackage', lambda x: x['teasers'].append({'kind': 'character', 'id': 'maren-kest'}))
# A character or place that waits for a chapter is never a teaser: Discover shows it to anyone.
teaser_case('teaser-gated.json', 'notAPackage', lambda x: x['teasers'][0].update(id='the-chorister'))
teaser_case('teaser-no-entry.json', 'notAPackage', lambda x: x['teasers'][0].update(id='the-quiet-ward'))
teaser_case('teaser-wrong-kind.json', 'notAPackage', lambda x: x['teasers'][0].update(id='the-vigil'))
teaser_case('teaser-long-clip.json', 'notAPackage', lambda x: x['teasers'][1].update(duration=30001))
teaser_case('teaser-no-chapter.json', 'notAPackage', lambda x: x['teasers'][3].update(chapter='the-tithe'))
teaser_case('teaser-wrong-media.json', 'notAPackage', lambda x: x['teasers'][1].update(audio='t-weir'))
teaser_case('teaser-unknown-kind.json', 'notAPackage', lambda x: x['teasers'][0].update(kind='poster'))
teaser_case('teaser-unknown-key.json', 'newerArke', lambda x: x['teasers'][3].update(caption='Low water'))
teaser_case('teaser-picture-only.json', 'ok', lambda x: x.update(characters=[], places=[], lore=[], teasers=[x['teasers'][3]]))
def world(version=3, productions=None, **extra):
    doc = {
        'format': 'arke-world-package', 'schemaVersion': version, 'id': 'undersong', 'edition': '2026-10-22', 'name': 'The Undersong',
        'keyArt': 'key-art', 'productions': productions if productions is not None else [], 'guide': 'guide',
        'assets': {'key-art': a('key-art.jpg', 'image/jpeg'), **assets},
    }
    doc.update(extra)
    return {key: value for key, value in doc.items() if value is not None}


book = [{'id': LEDGER, 'title': 'The Ledger of Nights', 'book': 'book'}]
with_book = world(productions=book)
with_book['assets']['book'] = a('the-ledger-of-nights/book.epub', 'application/epub+zip')
manifests = [
    ('world-guide-alone.json', 'ok', world()),
    ('world-guide-and-book.json', 'ok', with_book),
    ('world-schema2-guide.json', 'newerArke', world(version=2, productions=book)),
    ('world-nothing.json', 'notAPackage', world(guide=None)),
    ('world-guide-wrong-media.json', 'notAPackage', world(guide='g-maren')),
]
manifests[2][2]['assets']['book'] = with_book['assets']['book']
for name, expect, doc in manifests:
    w(name, doc)
    cases.append({'file': name, 'reader': 'manifest', 'expect': expect})
w('cases.json', {
    'note': 'SPEC-059 R-16: the guide cases both readers run, Arke Player arke_world (Dart) and ArkeStudio contracts (TypeScript). '
            'A guide file is read against assets.json; a "manifest" case is a world.json. "after" lists the chapter number each entry or section waits for.',
    'cases': cases,
})
print(len(cases), 'cases')
