import 'dart:collection';
import 'dart:convert';

import 'manifest.dart';

/// An interactive production's story document (SPEC-058 R-80, Player P18): an interactive movie or a
/// visual novel compiled by the Studio's contracts from its routing (SPEC-063 §2.1), with the clips or
/// beats each scene plays, the facts a route remembers, the choices with their guards and effects, and
/// the endings with their variants. Data only: nothing in it is run. The rules that play it are below,
/// a port of SPEC-063 R-6's evaluator held to the Studio's by shared fixtures (R-81).
const storyMediaType = 'application/vnd.arke.story+json';
const storyFormat = 'arke-story';
const storyVersion = 1;

/// The story document versions this Player plays (SPEC-058 R-82): a listed story of any other version
/// shows `Update app` and is never fetched.
const supportedStoryVersions = {storyVersion};

/// Media by role in a story document: a movie's clips are H.264 and AAC in MP4, a beat's picture and
/// its Tall are pictures, and a beat's voice is AAC in M4A (R-79).
const storyClipMediaTypes = {'video/mp4'};
const storyVoiceMediaTypes = {'audio/mp4'};

/// SPEC-063's bounds for routing, which a document compiled from it keeps, so whatever routing can
/// hold compiles: 32 facts, 16 values an enum, 64 characters a fact id or value (R-3); a condition 8
/// deep and 128 nodes (R-4); 32 effects a choice; an unavailable label of 256 and a reason of 600 (the
/// R-11 wire detail).
const maxStoryFacts = 32;
const maxStoryFactValues = 16;
const maxStoryFactLength = 64;
const maxStoryConditionDepth = 8;
const maxStoryConditionNodes = 128;
const maxStoryEffects = 32;

/// The document's own sizes, as contracts' `STORY_LIMITS` bound them: a story far past any authored
/// one is not a story to play on a phone.
const maxStoryScenes = 1000;
const maxStorySceneItems = 2000;
const maxStoryChoices = 4000;
const maxStoryPresentation = 20000;
const maxStoryEndings = 1000;
// Routing bounds no ending's variants, and First Contact's one ending has 104: 64 refused it.
const maxStoryVariants = 1000;

/// Text bounds, in characters: a scene's and a choice's id, a variant's id, and the words a listener
/// reads.
const maxStoryIdLength = 128;
const maxStoryVariantIdLength = 64;
const maxStorySceneTitleLength = 500;
const maxStoryLabelLength = 600;
const maxStoryClosedLabelLength = 256;
const maxStoryReasonLength = 600;
const maxStoryEndingTitleLength = 256;
const maxStorySpeakerLength = 200;
const maxStoryTextLength = 20000;

enum StoryKind { movie, novel }

/// The production's aspect (SPEC-019 R-36), which the Player plays it at (P18 rules 1 and 2).
enum StoryShape {
  wide('16:9'),
  tall('9:16');

  const StoryShape(this.label);

  /// As the document writes it.
  final String label;
}

enum StoryFactType { boolean, enumeration }

/// A fact a route remembers: a Boolean, or one of a few named values, and where every route starts.
/// It has no label: a listener never sees a fact (P18 call 23).
class StoryFact {
  const StoryFact({required this.id, required this.type, required this.initial, this.values = const []});
  final String id;
  final StoryFactType type;

  /// An enum's values, in order; empty for a Boolean.
  final List<String> values;

  /// The default: a `bool` or one of [values].
  final Object initial;

  /// Whether [value] is one this fact can hold, by type as well as value: `"true"` is not `true`.
  bool accepts(Object? value) => type == StoryFactType.boolean ? value is bool : value is String && values.contains(value);
}

/// A guard (SPEC-063 R-4): equality with a declared literal, `not`, `all` and `any`, and nothing else.
sealed class StoryCondition {
  const StoryCondition();

  /// Whether it holds in [facts]. A fact the facts do not hold throws, as the Studio's evaluator
  /// does: a read document never names one.
  bool holds(Map<String, Object> facts);
}

class StoryIs extends StoryCondition {
  const StoryIs(this.fact, this.value);
  final String fact;

  /// A `bool` or a `String`.
  final Object value;

  @override
  bool holds(Map<String, Object> facts) {
    if (!facts.containsKey(fact)) throw StoryRuleError('Unknown story fact: $fact');
    return facts[fact] == value;
  }
}

class StoryNot extends StoryCondition {
  const StoryNot(this.arg);
  final StoryCondition arg;

  @override
  bool holds(Map<String, Object> facts) => !arg.holds(facts);
}

class StoryAll extends StoryCondition {
  const StoryAll(this.args);
  final List<StoryCondition> args;

  @override
  bool holds(Map<String, Object> facts) => args.every((arg) => arg.holds(facts));
}

class StoryAny extends StoryCondition {
  const StoryAny(this.args);
  final List<StoryCondition> args;

  @override
  bool holds(Map<String, Object> facts) => args.any((arg) => arg.holds(facts));
}

/// A missing guard holds (R-4).
bool _holds(StoryCondition? when, Map<String, Object> facts) => when == null || when.holds(facts);

/// What a choice remembers: a fact set to a literal.
class StoryEffect {
  const StoryEffect(this.fact, this.value);
  final String fact;
  final Object value;
}

/// A movie's clip: a window into an MP4, from and to on its own clock.
class StoryClip {
  const StoryClip({required this.asset, required this.from, required this.to});

  /// An asset id.
  final String asset;
  final Duration from;
  final Duration to;
}

/// A visual novel's beat: a picture and its Tall, who speaks, the line, and its voice when voiced.
class StoryBeat {
  const StoryBeat({required this.picture, this.tall, this.speaker, this.line, this.voice});

  /// An asset id, as [tall] and [voice] are.
  final String picture;
  final String? tall;

  /// Absent for narration.
  final String? speaker;

  /// Absent for a picture held without a line.
  final String? line;
  final String? voice;
}

class StoryScene {
  const StoryScene({required this.id, required this.title, this.clips = const [], this.beats = const []});
  final String id;
  final String title;

  /// A movie's scene plays clips, a novel's reads beats; never both.
  final List<StoryClip> clips;
  final List<StoryBeat> beats;

  /// How many clips or beats it has: what [StoryPresentation.index] and [StoryStep.play] index into.
  int get length => clips.length + beats.length;
}

/// A clip or beat that plays only while its guard holds (SPEC-063 R-7), named by its index in its
/// scene. A clip or beat no row names always plays.
class StoryPresentation {
  const StoryPresentation({required this.scene, required this.index, required this.when});
  final String scene;
  final int index;
  final StoryCondition when;
}

/// What a closed choice says in its place (SPEC-063 R-11): its reason, and a label in place of its own.
class StoryUnavailable {
  const StoryUnavailable({required this.reason, this.label});
  final String? label;
  final String reason;
}

class StoryChoice {
  const StoryChoice({required this.id, required this.from, required this.to, required this.label, this.when, this.effects = const [], this.unavailable});
  final String id;
  final String from;
  final String to;
  final String label;
  final StoryCondition? when;
  final List<StoryEffect> effects;

  /// Absent, a choice whose guard fails is hidden.
  final StoryUnavailable? unavailable;
}

/// One of an ending's named outcomes (SPEC-063 R-10): its guard, or the fallback that covers the rest.
class StoryEndingVariant {
  const StoryEndingVariant({required this.id, required this.title, required this.text, this.when, this.fallback = false});
  final String id;
  final String title;
  final String text;

  /// Null on the fallback.
  final StoryCondition? when;
  final bool fallback;
}

/// An ending scene: its title and, in a stateful story, its variants. A story compiled from legacy
/// routing has none, and its ending is its title.
class StoryEnding {
  const StoryEnding({required this.scene, required this.title, this.variants = const []});
  final String scene;
  final String title;
  final List<StoryEndingVariant> variants;
}

class StoryDocument {
  StoryDocument({
    required this.kind,
    required this.shape,
    required this.start,
    required this.fingerprint,
    required this.facts,
    required List<StoryScene> scenes,
    required this.presentation,
    required this.choices,
    required List<StoryEnding> endings,
  }) : scenes = UnmodifiableMapView({for (final scene in scenes) scene.id: scene}),
       endings = UnmodifiableMapView({for (final ending in endings) ending.scene: ending}),
       _choices = {for (final choice in choices) choice.id: choice};

  final StoryKind kind;
  final StoryShape shape;

  /// The first scene's id.
  final String start;

  /// The content fingerprint of SPEC-063 R-14, `sha256:<hex>`: a saved route is replayed on a
  /// document whose fingerprint is not its own before it is trusted (R-88).
  final String fingerprint;

  /// In declared order.
  final List<StoryFact> facts;

  /// By id, in the document's order.
  final Map<String, StoryScene> scenes;
  final List<StoryPresentation> presentation;

  /// In authored order, the order a scene offers them in (SPEC-063 R-6).
  final List<StoryChoice> choices;
  final Map<String, StoryChoice> _choices;

  /// By scene id.
  final Map<String, StoryEnding> endings;

  StoryChoice? choice(String id) => _choices[id];

  /// Every asset the document names.
  Set<String> get assetIds => {
    for (final scene in scenes.values) ...[
      for (final clip in scene.clips) clip.asset,
      for (final beat in scene.beats) ...[beat.picture, ?beat.tall, ?beat.voice],
    ],
  };
}

sealed class StoryRead {
  const StoryRead();
}

class StoryOk extends StoryRead {
  const StoryOk(this.document);
  final StoryDocument document;
}

class StoryRefused extends StoryRead {
  const StoryRefused(this.refusal, this.reason);
  final WorldRefusal refusal;

  /// For a log, never the screen.
  final String reason;
}

final _sceneId = RegExp(r'^sc_[a-z0-9-]+$');
final _choiceId = RegExp(r'^ch_[a-z0-9-]+$');
final _factId = RegExp(r'^[a-z][a-z0-9-]*$');
final _fingerprint = RegExp(r'^sha256:[a-f0-9]{64}$');

class _Refuse implements Exception {
  const _Refuse(this.refusal, this.reason);
  final WorldRefusal refusal;
  final String reason;
}

/// Reads a story document against its package's inventory, as strictly as the music document
/// (SPEC-058 R-80): an unknown key, a newer version or a required capability is `Made with a newer
/// Arke`. An id that repeats; a choice, presentation row or ending naming a scene that is not there; a
/// guard or effect naming a fact or value that is not declared; an asset missing or not of its kind;
/// an ending with an outgoing choice; or a document past SPEC-063's bounds is not an Arke package.
/// Only `metadata` objects are ignorable, and not inside a condition or an effect, whose shapes are the
/// rules' own. The fingerprint is not recomputed: it is the identity a save is checked against, and the
/// package's hashes cover the bytes.
StoryRead readStory(String text, Map<String, WorldAsset> assets) {
  try {
    return StoryOk(_read(text, assets));
  } on _Refuse catch (refused) {
    return StoryRefused(refused.refusal, refused.reason);
  }
}

Never _notAPackage(String reason) => throw _Refuse(WorldRefusal.notAPackage, reason);
Never _newer(String reason) => throw _Refuse(WorldRefusal.newerArke, reason);

Map<String, Object?> _object(Object? value, String what, Set<String> keys, {bool ignorable = true}) {
  if (value is! Map<String, Object?>) _notAPackage('$what is not an object');
  final unknown = value.keys.where((key) => !keys.contains(key) && !(ignorable && key == 'metadata'));
  if (unknown.isNotEmpty) _newer('$what keys ${unknown.join(', ')}');
  return value;
}

List<Object?> _list(Object? value, String what, {int min = 0, required int max}) =>
    value is List<Object?> && value.length >= min && value.length <= max ? value : _notAPackage(what);

String _text(Object? value, String what, {int max = 400, bool empty = false}) =>
    value is String && (empty || value.trim().isNotEmpty) && value.length <= max ? value : _notAPackage(what);

String _match(Object? value, RegExp pattern, String what, {int max = maxStoryIdLength}) =>
    value is String && value.length <= max && pattern.hasMatch(value) ? value : _notAPackage(what);

Duration _ms(Object? value, String what) => value is int && value >= 0 ? Duration(milliseconds: value) : _notAPackage(what);

StoryDocument _read(String text, Map<String, WorldAsset> assets) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    _notAPackage('the story document is not JSON');
  }
  if (decoded is! Map<String, Object?> || decoded['format'] != storyFormat) _notAPackage('not an $storyFormat');
  final version = decoded['version'];
  if (version is! int) _notAPackage('no version');
  if (version > storyVersion) _newer('story version $version');
  if (version != storyVersion) _notAPackage('story version $version');
  final requires = decoded['requires'] ?? const <Object?>[];
  if (requires is! List<Object?>) _notAPackage('requires is not a list');
  if (requires.isNotEmpty) _newer('requires ${requires.join(', ')}');
  final json = _object(decoded, 'the story document', {
    'format',
    'version',
    'requires',
    'kind',
    'shape',
    'start',
    'fingerprint',
    'facts',
    'scenes',
    'presentation',
    'choices',
    'endings',
  });

  final kind = StoryKind.values.where((kind) => kind.name == json['kind']).firstOrNull ?? _notAPackage('kind');
  final shape = StoryShape.values.where((shape) => shape.label == json['shape']).firstOrNull ?? _notAPackage('shape');
  final fingerprint = json['fingerprint'];
  if (fingerprint is! String || !_fingerprint.hasMatch(fingerprint)) _notAPackage('fingerprint');

  // The facts first: every guard and effect after them is checked against what they declare.
  final facts = <String, StoryFact>{};
  for (final raw in _list(json['facts'], 'facts', max: maxStoryFacts)) {
    if (raw is! Map<String, Object?>) _notAPackage('a fact is not an object');
    // Its type says its shape: a Boolean names no values, so one that does names a key this reader
    // does not know. No fact names a label: a listener never sees one (P18 call 23).
    final type = raw['type'];
    if (type != 'boolean' && type != 'enum') _notAPackage('a fact type');
    final f = _object(raw, 'a fact', type == 'boolean' ? {'id', 'type', 'default'} : {'id', 'type', 'values', 'default'});
    final id = _match(f['id'], _factId, 'fact id', max: maxStoryFactLength);
    if (facts.containsKey(id)) _notAPackage('fact $id repeats');
    final StoryFact fact;
    switch (type) {
      case 'boolean':
        fact = StoryFact(id: id, type: StoryFactType.boolean, initial: f['default'] is bool ? f['default']! : _notAPackage('fact $id default'));
      default:
        final values = [
          for (final value in _list(f['values'], 'fact $id values', min: 1, max: maxStoryFactValues))
            value is String && value.isNotEmpty && value.length <= maxStoryFactLength ? value : _notAPackage('fact $id value'),
        ];
        if (values.toSet().length != values.length) _notAPackage('fact $id: a value repeats');
        final initial = f['default'];
        if (initial is! String || !values.contains(initial)) _notAPackage('fact $id default');
        fact = StoryFact(id: id, type: StoryFactType.enumeration, values: List.unmodifiable(values), initial: initial);
    }
    facts[id] = fact;
  }

  Object literal(Object? fact, Object? value, String what) {
    final declared = fact is String ? facts[fact] : null;
    if (declared == null) _notAPackage('$what names a fact that is not declared');
    if (!declared.accepts(value)) _notAPackage('$what: a value ${declared.id} cannot hold');
    return value!;
  }

  // A guard is a closed tree (SPEC-063 R-4), counted as the Studio counts it: depth from 1 at the
  // root, every node at most once towards 128.
  StoryCondition condition(Object? raw, String what) {
    var nodes = 0;
    StoryCondition visit(Object? value, int depth) {
      if (++nodes > maxStoryConditionNodes || depth > maxStoryConditionDepth) _notAPackage('$what: a condition past its size');
      if (value is! Map<String, Object?>) _notAPackage('$what: a condition is not an object');
      switch (value['op']) {
        case 'eq':
          final c = _object(value, '$what condition', {'op', 'fact', 'value'}, ignorable: false);
          final literalValue = literal(c['fact'], c['value'], what);
          return StoryIs(c['fact']! as String, literalValue);
        case 'not':
          final c = _object(value, '$what condition', {'op', 'arg'}, ignorable: false);
          return StoryNot(visit(c['arg'], depth + 1));
        case final op && ('all' || 'any'):
          final c = _object(value, '$what condition', {'op', 'args'}, ignorable: false);
          final args = [for (final arg in _list(c['args'], '$what: $op', min: 1, max: maxStoryConditionNodes)) visit(arg, depth + 1)];
          return op == 'all' ? StoryAll(List.unmodifiable(args)) : StoryAny(List.unmodifiable(args));
        default:
          _notAPackage('$what: an unknown condition');
      }
    }

    return visit(raw, 1);
  }

  String? asset(Object? id, Set<String> mediaTypes, String what) {
    if (id == null) return null;
    if (id is! String || assets[id] == null || !mediaTypes.contains(assets[id]!.mediaType)) _notAPackage(what);
    return id;
  }

  final scenes = <String, StoryScene>{};
  for (final raw in _list(json['scenes'], 'scenes', min: 1, max: maxStoryScenes)) {
    final s = _object(raw, 'a scene', {'id', 'title', 'clips', 'beats'});
    final id = _match(s['id'], _sceneId, 'scene id');
    if (scenes.containsKey(id)) _notAPackage('scene $id repeats');
    // A movie plays clips and a novel reads beats (R-80); a scene of the other kind is not this story's.
    final own = kind == StoryKind.movie ? 'clips' : 'beats';
    if (s.containsKey(kind == StoryKind.movie ? 'beats' : 'clips')) _notAPackage('scene $id: a ${kind.name}\'s scene has $own only');
    final items = _list(s[own], 'scene $id $own', min: 1, max: maxStorySceneItems);
    final clips = <StoryClip>[];
    final beats = <StoryBeat>[];
    for (final (index, item) in items.indexed) {
      final where = 'scene $id ${own == 'clips' ? 'clip' : 'beat'} ${index + 1}';
      if (kind == StoryKind.movie) {
        final c = _object(item, where, {'asset', 'from', 'to'});
        final from = _ms(c['from'], '$where from');
        final to = _ms(c['to'], '$where to');
        if (to <= from) _notAPackage('$where: it ends before it starts');
        clips.add(StoryClip(asset: asset(c['asset'], storyClipMediaTypes, '$where asset') ?? _notAPackage('$where asset'), from: from, to: to));
      } else {
        final b = _object(item, where, {'picture', 'tall', 'speaker', 'line', 'voice'});
        // Every beat has its picture: one that would keep the last beat's is given its own at export.
        beats.add(
          StoryBeat(
            picture: asset(b['picture'], pictureMediaTypes, '$where picture') ?? _notAPackage('$where picture'),
            tall: asset(b['tall'], pictureMediaTypes, '$where tall'),
            speaker: b['speaker'] == null ? null : _text(b['speaker'], '$where speaker', max: maxStorySpeakerLength),
            line: b['line'] == null ? null : _text(b['line'], '$where line', max: maxStoryTextLength),
            voice: asset(b['voice'], storyVoiceMediaTypes, '$where voice'),
          ),
        );
      }
    }
    scenes[id] = StoryScene(
      id: id,
      title: _text(s['title'], 'scene $id title', max: maxStorySceneTitleLength),
      clips: List.unmodifiable(clips),
      beats: List.unmodifiable(beats),
    );
  }
  String scene(Object? id, String what) => id is String && scenes.containsKey(id) ? id : _notAPackage('$what names a scene that is not there');

  final start = scene(json['start'], 'start');

  final presentation = <StoryPresentation>[];
  final guarded = <(String, int)>{};
  for (final raw in _list(json['presentation'], 'presentation', max: maxStoryPresentation)) {
    final p = _object(raw, 'a presentation row', {'scene', 'index', 'when'});
    final at = scene(p['scene'], 'a presentation row');
    final index = p['index'];
    if (index is! int || index < 0 || index >= scenes[at]!.length) _notAPackage('a presentation row of $at names no clip or beat');
    if (!guarded.add((at, index))) _notAPackage('a presentation row of $at repeats');
    presentation.add(StoryPresentation(scene: at, index: index, when: condition(p['when'], 'presentation of $at')));
  }

  final choices = <StoryChoice>[];
  final choiceIds = <String>{};
  for (final raw in _list(json['choices'], 'choices', max: maxStoryChoices)) {
    final c = _object(raw, 'a choice', {'id', 'from', 'to', 'label', 'when', 'effects', 'unavailable'});
    final id = _match(c['id'], _choiceId, 'choice id');
    if (!choiceIds.add(id)) _notAPackage('choice $id repeats');
    final what = 'choice $id';
    final assigned = <String>{};
    final effects = [
      for (final rawEffect in _list(c['effects'], '$what effects', max: maxStoryEffects))
        () {
          final e = _object(rawEffect, 'an effect of $what', {'fact', 'value'}, ignorable: false);
          final value = literal(e['fact'], e['value'], what);
          // Effects are atomic (SPEC-063 R-5): one choice sets a fact once.
          if (!assigned.add(e['fact']! as String)) _notAPackage('$what sets ${e['fact']} twice');
          return StoryEffect(e['fact']! as String, value);
        }(),
    ];
    StoryUnavailable? unavailable;
    if (c['unavailable'] != null) {
      final u = _object(c['unavailable'], '$what unavailable', {'label', 'reason'});
      unavailable = StoryUnavailable(
        label: u['label'] == null ? null : _text(u['label'], '$what unavailable label', max: maxStoryClosedLabelLength),
        reason: _text(u['reason'], '$what unavailable reason', max: maxStoryReasonLength),
      );
    }
    choices.add(
      StoryChoice(
        id: id,
        from: scene(c['from'], what),
        to: scene(c['to'], what),
        label: _text(c['label'], '$what label', max: maxStoryLabelLength),
        when: c['when'] == null ? null : condition(c['when'], what),
        effects: List.unmodifiable(effects),
        unavailable: unavailable,
      ),
    );
  }

  final endings = <StoryEnding>[];
  final endingScenes = <String>{};
  for (final raw in _list(json['endings'], 'endings', max: maxStoryEndings)) {
    final e = _object(raw, 'an ending', {'scene', 'title', 'variants'});
    final at = scene(e['scene'], 'an ending');
    if (!endingScenes.add(at)) _notAPackage('$at is an ending twice');
    // An ending offers nothing after it (SPEC-063 R-10).
    if (choices.any((choice) => choice.from == at)) _notAPackage('the ending at $at has an outgoing choice');
    final variants = <StoryEndingVariant>[];
    if (e['variants'] != null) {
      final ids = <String>{};
      for (final rawVariant in _list(e['variants'], 'the ending at $at variants', min: 1, max: maxStoryVariants)) {
        final v = _object(rawVariant, 'a variant of the ending at $at', {'id', 'title', 'text', 'when', 'fallback'});
        final id = switch (v['id']) {
          final String id when id.isNotEmpty && id.length <= maxStoryVariantIdLength => id,
          _ => _notAPackage('a variant id at $at'),
        };
        if (!ids.add(id)) _notAPackage('variant $id at $at repeats');
        final fallback = v['fallback'];
        if (fallback != null && fallback != true) _notAPackage('variant $id at $at fallback');
        // A fallback has no guard, and every other variant has one (SPEC-063 §2.1).
        if (fallback == true ? v['when'] != null : v['when'] == null) _notAPackage('variant $id at $at guard');
        variants.add(
          StoryEndingVariant(
            id: id,
            title: _text(v['title'], 'variant $id at $at title', max: maxStoryEndingTitleLength),
            text: _text(v['text'], 'variant $id at $at text', max: maxStoryTextLength, empty: true),
            when: fallback == true ? null : condition(v['when'], 'variant $id at $at'),
            fallback: fallback == true,
          ),
        );
      }
      if (variants.where((variant) => variant.fallback).length > 1) _notAPackage('the ending at $at has two fallbacks');
    }
    endings.add(
      StoryEnding(
        scene: at,
        title: _text(e['title'], 'the ending at $at title', max: maxStoryEndingTitleLength),
        variants: List.unmodifiable(variants),
      ),
    );
  }

  return StoryDocument(
    kind: kind,
    shape: shape,
    start: start,
    fingerprint: fingerprint,
    facts: List.unmodifiable(facts.values),
    scenes: scenes.values.toList(),
    presentation: List.unmodifiable(presentation),
    choices: List.unmodifiable(choices),
    endings: endings,
  );
}

// ---- The rules (SPEC-063 R-6, R-7, R-10, R-11, R-13, R-14) --------------------------------------------

/// A rule the document cannot keep in the state a route reaches: an ending whose variants overlap, or
/// that none covers. The Studio's evaluator throws the same, and its export refuses a story that can
/// reach one (SPEC-063 R-16), so a published story never does.
class StoryRuleError implements Exception {
  const StoryRuleError(this.message);
  final String message;

  @override
  String toString() => 'StoryRuleError: $message';
}

/// A choice in a scene, as the Player offers it: open, or closed in its place with its reason
/// (SPEC-063 R-11, P18 rule 3).
class StoryOption {
  const StoryOption(this.choice, {required this.open});
  final StoryChoice choice;

  /// False for a closed choice, which keeps its place, dimmed, and cannot be chosen.
  final bool open;

  /// What it says: a closed choice's `unavailable.label` in place of its own, when the author gave one.
  String get label => open ? choice.label : choice.unavailable?.label ?? choice.label;

  /// Why a closed choice is closed; null on an open one.
  String? get reason => open ? null : choice.unavailable?.reason;
}

/// An ending as a route resolves it: its variant (null in a story with none), title and text.
class StoryEndingResolved {
  const StoryEndingResolved({required this.scene, required this.title, this.variant, this.text});
  final String scene;
  final String? variant;
  final String title;
  final String? text;
}

/// Where a route leaves a listener: arrived at [scene] with [facts], what plays there and what it
/// offers, or how it ends.
class StoryStep {
  const StoryStep({required this.route, required this.scene, required this.facts, required this.options, required this.play, this.ending});

  /// The choice ids taken to get here, in order.
  final List<String> route;
  final String scene;

  /// Every declared fact's value, in declared order. Never shown (P18 call 23).
  final Map<String, Object> facts;

  /// The scene's choices that show, in authored order: the open ones and, in their places, the closed
  /// ones whose author gave a reason. A closed choice without one is hidden.
  final List<StoryOption> options;

  /// The indices of the scene's clips or beats that play in this state, ascending (SPEC-063 R-7, R-8).
  /// Empty, the scene goes straight to its choices or its ending (R-11).
  final List<int> play;

  /// The resolved ending at an ending scene; null anywhere else.
  final StoryEndingResolved? ending;

  /// The choices a listener can take from here, in authored order: the legal next steps.
  List<StoryChoice> get open => [
    for (final option in options)
      if (option.open) option.choice,
  ];

  List<StoryOption> get closed => [
    for (final option in options)
      if (!option.open) option,
  ];

  /// Where nothing more can be chosen: an ending, or a scene with no open choice.
  bool get isEnd => ending != null || open.isEmpty;

  /// The one way on, when it is all this step offers (P19 rule 4): exactly one open choice, and no
  /// closed choice shown with its reason. A story takes it without stopping and shows nothing for it,
  /// though it is still a step of the route, with its effects. Null at a choice of two or more — a
  /// closed choice shown with its reason counts as one of them (rule 3) — at an ending, and where
  /// nothing is open. The Studio's player keeps the same definition (Studio 246).
  StoryChoice? get loneWay => options.length == 1 && options.single.open ? options.single.choice : null;
}

/// A route replayed on a document (R-88): every step legal, or the first that is not.
sealed class StoryReplay {
  const StoryReplay();
}

class StoryReplayed extends StoryReplay {
  const StoryReplayed(this.step);
  final StoryStep step;
}

class StoryRouteBroken extends StoryReplay {
  const StoryRouteBroken({required this.at, required this.choice, required this.before});

  /// The index in the route of the first choice that cannot be taken.
  final int at;

  /// Its id.
  final String choice;

  /// Where the route stood before it: the last state every step to which is legal.
  final StoryStep before;
}

/// A route that is not legal on its document (SPEC-063 R-6): a choice that is not there, not from the
/// scene the route has reached, or whose guard fails there.
class StoryRouteRefused implements Exception {
  const StoryRouteRefused(this.broken);
  final StoryRouteBroken broken;

  @override
  String toString() => 'StoryRouteRefused: invalid route at ${broken.choice} (step ${broken.at + 1})';
}

/// A point on a route before its projection: the scene and the facts. What [_advance] folds.
typedef _Point = ({String scene, Map<String, Object> facts});

_Point _defaults(StoryDocument document) => (scene: document.start, facts: {for (final fact in document.facts) fact.id: fact.initial});

/// One step of the fold (SPEC-063 R-5): the choice must be from this scene and open in these facts;
/// its effects apply all at once, then the route enters its scene. Null when it cannot be taken.
_Point? _advance(StoryDocument document, _Point point, String id) {
  final choice = document.choice(id);
  if (choice == null || choice.from != point.scene || !_holds(choice.when, point.facts)) return null;
  return (scene: choice.to, facts: {...point.facts, for (final effect in choice.effects) effect.fact: effect.value});
}

/// The ending at [scene] in [facts] (SPEC-063 R-10): exactly one non-fallback variant that holds, else
/// the fallback. Null at a scene that is not an ending.
StoryEndingResolved? _ending(StoryDocument document, String scene, Map<String, Object> facts) {
  final ending = document.endings[scene];
  if (ending == null) return null;
  if (ending.variants.isEmpty) return StoryEndingResolved(scene: scene, title: ending.title);
  final matches = ending.variants.where((variant) => !variant.fallback && _holds(variant.when, facts)).toList();
  if (matches.length > 1) throw StoryRuleError('Overlapping ending variants at $scene');
  final selected = matches.firstOrNull ?? ending.variants.where((variant) => variant.fallback).firstOrNull;
  if (selected == null) throw StoryRuleError('No matching ending at $scene');
  return StoryEndingResolved(scene: scene, variant: selected.id, title: selected.title, text: selected.text);
}

StoryStep _project(StoryDocument document, _Point point, List<String> route) {
  final rows = document.presentation.where((row) => row.scene == point.scene);
  final facts = Map<String, Object>.unmodifiable(point.facts);
  return StoryStep(
    route: List.unmodifiable(route),
    scene: point.scene,
    facts: facts,
    options: List.unmodifiable([
      for (final choice in document.choices)
        if (choice.from == point.scene)
          if (_holds(choice.when, facts)) StoryOption(choice, open: true) else if (choice.unavailable != null) StoryOption(choice, open: false),
    ]),
    play: List.unmodifiable([
      for (var index = 0; index < document.scenes[point.scene]!.length; index++)
        if (rows.every((row) => row.index != index || row.when.holds(facts))) index,
    ]),
    ending: _ending(document, point.scene, facts),
  );
}

/// Folds the defaults over [route], a list of choice ids, checking every step (SPEC-063 R-6), and
/// reports either where the route stands or the first step that is not legal (R-88: a saved route
/// replayed on an updated document).
StoryReplay replayStory(StoryDocument document, Iterable<String> route) {
  var point = _defaults(document);
  final taken = <String>[];
  for (final id in route) {
    final next = _advance(document, point, id);
    if (next == null) return StoryRouteBroken(at: taken.length, choice: id, before: _project(document, point, taken));
    point = next;
    taken.add(id);
  }
  return StoryReplayed(_project(document, point, taken));
}

/// Where [route] stands on [document]; throws [StoryRouteRefused] when a step is not legal.
StoryStep evaluateStory(StoryDocument document, Iterable<String> route) => switch (replayStory(document, route)) {
  StoryReplayed(:final step) => step,
  final StoryRouteBroken broken => throw StoryRouteRefused(broken),
};

/// Where every route begins: the start scene with every fact at its default.
StoryStep startStory(StoryDocument document) => evaluateStory(document, const []);

/// Takes [choice] from [step]; throws [StoryRouteRefused] when it is not open there.
StoryStep chooseStory(StoryDocument document, StoryStep step, String choice) => evaluateStory(document, [...step.route, choice]);

/// Where a scene played through goes on to by itself (P19 rule 4): [step]'s lone way taken, and the
/// lone way of every scene after it that plays nothing, so a story stops only where something plays,
/// at a choice of two or more, or at an end. Each lone way is a step of the route, with its effects,
/// so the route replays. [step] itself when it has no lone way.
///
/// Lone ways round a loop of scenes that play nothing would never reach any of those, and no author
/// means one; the walk gives up after [maxStoryScenes] of them, at a lone way, which is then shown.
StoryStep takeLoneWays(StoryDocument document, StoryStep step) {
  var at = step;
  for (var taken = 0; taken < maxStoryScenes; taken++) {
    final way = at.loneWay;
    if (way == null) return at;
    at = chooseStory(document, at, way.id);
    if (at.play.isNotEmpty) return at;
  }
  return at;
}

/// `Choose again` at the route's [index]th choice (SPEC-063 R-13, SPEC-058 R-86): the route is cut
/// before it and what is kept is replayed, so every later consequence goes with it. The step returned
/// is that decision again, at the scene the choice was made from.
StoryStep chooseStoryAgain(StoryDocument document, List<String> route, int index) {
  RangeError.checkValidIndex(index, route, 'index');
  return evaluateStory(document, route.sublist(0, index));
}
