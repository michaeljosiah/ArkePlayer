import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'catalogue.dart';

/// Arke's list of worlds kept at one address as well as in the app (SPEC-058 R-31, Player P12 rule
/// 1): fetched over HTTPS at most once a day and kept on the phone, so a newer edition of a world
/// shows without an update, and Worlds still shows offline. A list that will not read is ignored;
/// so is one older than the list already kept ([newestCatalogue] decides between kept and shipped).
class HostedCatalogue {
  HostedCatalogue({required this.url, required this.kept, HttpClient Function()? httpClient, DateTime Function()? now, this.every = const Duration(days: 1)})
    : _httpClient = httpClient ?? HttpClient.new,
      _now = now ?? (() => DateTime.now().toUtc());

  /// Arke's address. The app's is HTTPS, as a world's package is, and its test says so; a list's
  /// pins are checked as the shipped list's are, whichever address it came from.
  final Uri url;

  /// Where the fetched list is kept, with when it was last asked for.
  final File kept;
  final Duration every;
  final HttpClient Function() _httpClient;
  final DateTime Function() _now;

  /// A list is a few kilobytes; anything far larger is not one.
  static const maxBytes = 1024 * 1024;
  static const _timeout = Duration(seconds: 20);

  Future<({DateTime? fetchedAt, Catalogue? list})> _read() async {
    try {
      final json = jsonDecode(await kept.readAsString());
      if (json is! Map<String, Object?>) return (fetchedAt: null, list: null);
      final fetchedAt = DateTime.tryParse(json['fetchedAt'] as String? ?? '');
      final list = json['list'] is Map<String, Object?> ? parseCatalogue(jsonEncode(json['list'])) : null;
      return (fetchedAt: fetchedAt, list: list);
    } on Object {
      return (fetchedAt: null, list: null);
    }
  }

  /// The list kept from the last fetch, if any.
  Future<Catalogue?> keptList() async => (await _read()).list;

  /// Fetches the list when the last ask was more than [every] ago, and keeps it when it reads and is
  /// newer than the one kept. Returns the list kept afterwards. Never throws: offline, a refusal or a
  /// broken list leaves what was kept.
  Future<Catalogue?> refresh({bool force = false}) async {
    final was = await _read();
    final now = _now();
    if (!force && was.fetchedAt != null && now.difference(was.fetchedAt!) < every) return was.list;
    String? text;
    Catalogue? fetched;
    try {
      text = await _get();
      fetched = parseCatalogue(text);
    } on Object {
      fetched = null;
    }
    final newer = fetched != null && fetched.serial > (was.list?.serial ?? -1);
    await _write(now, newer ? text : null);
    return newer ? fetched : was.list;
  }

  Future<String> _get() async {
    final client = _httpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(url).timeout(_timeout);
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) throw HttpException('status ${response.statusCode}', uri: url);
      final bytes = <int>[];
      await for (final chunk in response.timeout(_timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > maxBytes) throw const FormatException('catalogue too large');
      }
      return utf8.decode(bytes);
    } finally {
      client.close(force: true);
    }
  }

  /// Writes when the list was asked for, and the list to keep: the fetched one's own text, or the
  /// one kept before.
  Future<void> _write(DateTime fetchedAt, String? fetchedText) async {
    Object? list;
    if (fetchedText != null) {
      list = jsonDecode(fetchedText);
    } else {
      try {
        list = (jsonDecode(await kept.readAsString()) as Map<String, Object?>)['list'];
      } on Object {
        list = null;
      }
    }
    await kept.parent.create(recursive: true);
    final next = File('${kept.path}.next');
    await next.writeAsString(jsonEncode({'fetchedAt': fetchedAt.toIso8601String(), 'list': ?list}), flush: true);
    await next.rename(kept.path);
  }
}
