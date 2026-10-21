import 'package:arke_world/arke_world.dart';

/// One showing of Text: words that fit the lines there are, and the span they are heard over.
class Cue {
  const Cue({required this.text, required this.from, required this.to});

  final String text;
  final Duration from;
  final Duration to;
}

/// Text's cues (SPEC-047 R-70, SPEC-058 R-24), as the Studio's shared player makes them: a long
/// passage advances through all its words in pieces that fit, never clipped, cut short or set
/// smaller. Measured word intervals are used where the phrase has them, and clear between words;
/// otherwise each word takes its character-weighted share of the phrase.
class Captions {
  final _made = Expando<(Object, List<Cue>)>();

  /// The cue being heard [offset] into the chapter, if any. [fits] says whether a text fits the
  /// lines there are; [layout] names that measure, so cues are made again only when it changes.
  Cue? at(ListeningPhrase phrase, Duration offset, Object layout, bool Function(String text) fits) {
    final made = _made[phrase];
    final cues = made != null && made.$1 == layout ? made.$2 : (_made[phrase] = (layout, cuesOf(phrase, fits))).$2;
    for (final cue in cues) {
      if (cue.from <= offset && offset < cue.to) return cue;
    }
    return null;
  }
}

/// Every cue of [phrase], in order; their texts joined are its words.
List<Cue> cuesOf(ListeningPhrase phrase, bool Function(String text) fits) {
  final cues = <Cue>[];
  Cue? held;
  void flush() {
    if (held != null) cues.add(held!);
    held = null;
  }

  for (final word in _words(phrase)) {
    if (held != null && !fits('${held!.text} ${word.text}')) flush();
    if (!fits(word.text)) {
      flush();
      // Even an unbroken word must not make a third line: keep every character and give its
      // pieces their share of the word's span, rather than clip it or shrink the type.
      final characters = word.text.runes.toList();
      for (var start = 0; start < characters.length;) {
        var low = 1, high = characters.length - start;
        while (low < high) {
          final mid = (low + high + 1) ~/ 2;
          if (fits(String.fromCharCodes(characters, start, start + mid))) {
            low = mid;
          } else {
            high = mid - 1;
          }
        }
        final end = start + low;
        cues.add(
          Cue(text: String.fromCharCodes(characters, start, end), from: _share(word, start, characters.length), to: _share(word, end, characters.length)),
        );
        start = end;
      }
      continue;
    }
    held = held == null ? word : Cue(text: '${held!.text} ${word.text}', from: held!.from, to: word.to);
    // End at a sentence, or at a substantial clause, before growing another cue.
    if (_sentenceEnd.hasMatch(word.text) || (held!.text.length >= 40 && _clauseEnd.hasMatch(word.text))) flush();
  }
  flush();
  return cues;
}

final _sentenceEnd = RegExp('[.!?…]["\'”’)\\]]*\$');
final _clauseEnd = RegExp('[,;:—]\$');

Duration _share(Cue word, int index, int count) => word.from + (word.to - word.from) * (index / count);

List<Cue> _words(ListeningPhrase phrase) {
  if (phrase.words.isNotEmpty) return [for (final word in phrase.words) Cue(text: word.text, from: word.at, to: word.end)];
  final text = phrase.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty || phrase.end <= phrase.at) return const [];
  final span = phrase.end - phrase.at;
  final parts = text.split(' ');
  final words = <Cue>[];
  var count = 0;
  for (final (i, part) in parts.indexed) {
    final weight = part.length + (i < parts.length - 1 ? 1 : 0);
    words.add(Cue(text: part, from: phrase.at + span * (count / text.length), to: phrase.at + span * ((count + weight) / text.length)));
    count += weight;
  }
  return words;
}
