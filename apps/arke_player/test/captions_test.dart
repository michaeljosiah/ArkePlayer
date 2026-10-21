import 'package:arke_player/features/players/application/captions.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter_test/flutter_test.dart';

// The Studio's cases for Text (SPEC-047 R-70; its client test/audiobook-player.test.ts), with its
// measure for a page without layout: 42 characters a line, two lines.
bool _fits(String text) => text.length <= 84;

Duration _s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

List<String> _shown(Captions captions, ListeningPhrase phrase, num seconds) {
  final seen = <String>[];
  for (var at = 0.0; at < seconds; at += 0.1) {
    final cue = captions.at(phrase, _s(at), 'test', _fits);
    if (cue != null && (seen.isEmpty || seen.last != cue.text)) seen.add(cue.text);
  }
  return seen;
}

void main() {
  test('a long passage advances through every word, never the next sentence early', () {
    const prose =
        'Maren watched the boats moving beyond the breakwater while the lamps slowly came on along the harbour wall and the last light went out over the sea. She stayed until the bell sounded again.';
    final phrase = ListeningPhrase(at: Duration.zero, end: _s(100), text: prose);
    final captions = Captions();
    expect(captions.at(phrase, Duration.zero, 'test', _fits)!.text, isNot(contains('She stayed')));
    final seen = _shown(captions, phrase, 100);
    expect(seen.every(_fits), isTrue);
    expect(seen.join(' '), prose, reason: 'no sentence, word or punctuation is omitted');
  });

  test('measured intervals are used, and Text clears between them', () {
    final phrase = ListeningPhrase(
      at: Duration.zero,
      end: _s(12),
      text: 'First. Last.',
      words: [
        ListeningWord(at: _s(2), end: _s(3), text: 'First.'),
        ListeningWord(at: _s(8), end: _s(9), text: 'Last.'),
      ],
    );
    final captions = Captions();
    expect(captions.at(phrase, _s(1), 'test', _fits), isNull);
    expect(captions.at(phrase, _s(2.5), 'test', _fits)?.text, 'First.');
    expect(captions.at(phrase, _s(4), 'test', _fits), isNull);
    expect(captions.at(phrase, _s(8.5), 'test', _fits)?.text, 'Last.');
  });

  test('an unbroken token is kept whole across cues, with nothing put inside it', () {
    final token = 'abcdefghij' * 30;
    final phrase = ListeningPhrase(at: Duration.zero, end: _s(60), text: token);
    expect(_shown(Captions(), phrase, 60).join(), token);
  });

  test('cues are made again when the measure changes', () {
    const text = 'The tide-clock keeps the drowned god’s hours, and nobody in Saltmouth winds it.';
    final phrase = ListeningPhrase(at: Duration.zero, end: _s(10), text: text);
    final captions = Captions();
    // A clause of forty characters or more ends a cue even where more would fit.
    expect(captions.at(phrase, Duration.zero, 'wide', (_) => true)!.text, 'The tide-clock keeps the drowned god’s hours,');
    expect(captions.at(phrase, Duration.zero, 'narrow', (t) => t.length <= 20)!.text, 'The tide-clock keeps');
  });
}
