import 'dart:convert';

import 'package:arke_publication/arke_publication.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

void main() {
  final bytes = utf8.encode('the tide is lower than it has ever been');
  final asset = PublicationAsset(href: 'media/a.txt', mediaType: 'text/plain', byteLength: bytes.length, sha256: sha256.convert(bytes).toString());
  Stream<List<int>> chunks(List<int> data) => Stream.fromIterable([data.sublist(0, 10), data.sublist(10)]);

  test('matching bytes pass', () async {
    expect(await checkAsset(asset, () => chunks(bytes)), AssetCheck.matches);
  });

  test('an absent file is missing', () async {
    expect(await checkAsset(asset, () => null), AssetCheck.missing);
  });

  test('a different length fails before the digest is trusted', () async {
    expect(await checkAsset(asset, () => chunks([...bytes, 33])), AssetCheck.wrongLength);
  });

  test('same length, different bytes fails the digest', () async {
    final changed = [...bytes]..[0] = bytes[0] ^ 1;
    expect(await checkAsset(asset, () => chunks(changed)), AssetCheck.wrongDigest);
  });
}
