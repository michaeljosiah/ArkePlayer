import 'dart:convert';
import 'dart:io';

import 'package:arke_player/features/players/application/listening_plan.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter_test/flutter_test.dart';

// The shared listening fixtures (SPEC-058 R-16), read here on the book's clock: Neap is 60 s with
// pictures at 5 s, 20 s (held 15 s, with a loop) and 40 s; The rail book follows it for 30 s.
final _fixtures = '${Directory.current.path}/../../packages/arke_world/test/fixtures/listening';

ListeningPlan _plan() {
  final assets = {
    for (final MapEntry(:key, value: raw) in (jsonDecode(File('$_fixtures/assets.json').readAsStringSync()) as Map<String, Object?>).entries)
      if (raw case {'path': final String path, 'mediaType': final String mediaType, 'byteLength': final int byteLength, 'sha256': final String sha256})
        key: WorldAsset(path: path, mediaType: mediaType, byteLength: byteLength, sha256: sha256),
  };
  final document = switch (readListening(File('$_fixtures/valid.json').readAsStringSync(), assets)) {
    ListeningOk(:final document) => document,
    ListeningRefused(:final reason) => throw StateError(reason),
  };
  return ListeningPlan(document: document, pathOf: (id) => 'files/$id');
}

Duration _s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

void main() {
  test('the chapters play back to back on one clock', () {
    final plan = _plan();
    expect(plan.starts, [Duration.zero, _s(60)]);
    expect(plan.locate(_s(70)), (1, _s(10)));
    expect(plan.locate(_s(200)), (1, _s(30)));
    expect(plan.timeOf('the-rail-book', _s(5)), _s(65));
    // A place in a chapter this edition no longer has starts the book again.
    expect(plan.timeOf('gone', _s(5)), Duration.zero);
    expect(plan.timeOf(null, _s(5)), Duration.zero);
  });

  test('the picture of the moment and the span it shows for', () {
    final plan = _plan();
    // Before the first picture, the chapter's opening (R-14).
    final opening = plan.shownAt(_s(1))!;
    expect((opening.path, opening.start, opening.end, opening.pushes), ('files/p001', Duration.zero, _s(5), true));

    final first = plan.shownAt(_s(5))!;
    expect((first.start, first.end, first.focus?.x, first.motionPath), (_s(5), _s(20), 0.42, null));
    expect(first.progressAt(_s(12.5)), 0.5);

    final held = plan.shownAt(_s(25))!;
    expect((held.path, held.end, held.motionPath, held.motionRepeats), ('files/p002', _s(35), 'files/m001', true));
    // A loop keeps its own movement: Slow push moves stills only.
    expect(held.pushes, isFalse);

    // After a hold ends, the opening again, from the hold's end to the next picture.
    final gap = plan.shownAt(_s(36))!;
    expect((gap.path, gap.start, gap.end), ('files/p001', _s(35), _s(40)));

    final last = plan.shownAt(_s(59.999))!;
    expect((last.path, last.end), ('files/p003', _s(60)));

    final next = plan.shownAt(_s(60.1))!;
    expect((next.path, next.start, next.end), ('files/p002', _s(60), _s(90)));
  });

  test('the phrase being heard', () {
    final plan = _plan();
    expect(plan.phraseAt(_s(1)), isNull);
    expect(plan.phraseAt(_s(1.3))?.text, 'The tide-clock keeps the drowned god’s hours.');
    expect(plan.phraseAt(_s(5.4))?.text, 'Nobody in Saltmouth winds it.');
    expect(plan.phraseAt(_s(61)), isNull);
  });
}
