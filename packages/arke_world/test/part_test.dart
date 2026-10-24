import 'dart:convert';
import 'dart:io';

import 'package:arke_world/arke_world.dart';
import 'package:test/test.dart';

// SPEC-058 R-46: these fixtures are the ones ArkeStudio's contracts read too, so both readers agree
// on every verdict and on what a part says it follows.
final _fixtures = '${Directory.current.path}/test/fixtures/part';

String _read(String name) => File('$_fixtures/$name').readAsStringSync();

void main() {
  group('the shared part cases (SPEC-058 R-46)', () {
    final cases = (jsonDecode(_read('cases.json')) as Map<String, Object?>)['cases']! as List<Object?>;
    for (final raw in cases.cast<Map<String, Object?>>()) {
      final file = raw['file']! as String;
      test(file, () {
        final read = readWorldManifest(_read(file));
        switch (raw['expect']) {
          case 'ok':
            expect(read, isA<WorldManifestOk>(), reason: read is WorldManifestRefused ? read.reason : null);
          case 'newerArke':
            expect((read as WorldManifestRefused).refusal, WorldRefusal.newerArke);
          case 'notAPackage':
            expect((read as WorldManifestRefused).refusal, WorldRefusal.notAPackage);
        }
        if (raw['part'] case final Map<String, Object?> part) {
          final read_ = (read as WorldManifestOk).manifest.part!;
          expect((read_.follows, read_.number), (part['follows'], part['number']));
          expect(read_.schedule?.day?.name, part['day']);
          expect(read_.schedule?.next == null ? null : dayText(read_.schedule!.next!), part['next']);
        }
      });
    }
  });

  test('a date that does not exist is not one', () {
    expect(parseDay('2026-02-30'), isNull);
    expect(parseDay('2026-11-06'), DateTime.utc(2026, 11, 6));
  });
}
