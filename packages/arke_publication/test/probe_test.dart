import 'dart:convert';
import 'dart:typed_data';

import 'package:arke_publication/arke_publication.dart';
import 'package:test/test.dart';

Uint8List _bytes(List<int> head) => Uint8List.fromList([...head, ...List.filled(128, 0)]);

FileFormat? _format(Probe probe) => probe is ProbeFormat ? probe.format : null;

void main() {
  test('PDF by its signature, whatever its name', () {
    expect(_format(probeFile(_bytes(ascii.encode('%PDF-1.7')), name: 'boards')), FileFormat.pdf);
  });

  test('EPUB by its stored mimetype entry', () {
    final head = [0x50, 0x4B, 0x03, 0x04, ...List.filled(26, 0), ...ascii.encode('mimetypeapplication/epub+zip')];
    expect(_format(probeFile(_bytes(head), name: 'almanac.epub')), FileFormat.epub);
  });

  test('a ZIP is a package or a comic by its name, and refused otherwise', () {
    final zip = _bytes([0x50, 0x4B, 0x03, 0x04]);
    expect(_format(probeFile(zip, name: 'meridian-dust.arke')), FileFormat.arkePackage);
    expect(_format(probeFile(zip, name: 'harbour.cbz')), FileFormat.cbz);
    expect((probeFile(zip, name: 'manuscript.docx') as ProbeRefused).refusal, ProbeRefusal.notSupported);
  });

  test('ISO media by its brand', () {
    List<int> ftyp(String brand) => [0, 0, 0, 32, ...ascii.encode('ftyp'), ...ascii.encode(brand)];
    expect(_format(probeFile(_bytes(ftyp('M4B ')), name: 'a')), FileFormat.m4b);
    expect(_format(probeFile(_bytes(ftyp('qt  ')), name: 'a')), FileFormat.mov);
    expect(_format(probeFile(_bytes(ftyp('isom')), name: 'reel.mp4')), FileFormat.mp4);
    expect((probeFile(_bytes(ftyp('M4P ')), name: 'song.m4p') as ProbeRefused).refusal, ProbeRefusal.protectedFile);
  });

  test('MP3 by its tag or frame sync', () {
    expect(_format(probeFile(_bytes(ascii.encode('ID3')), name: 'a')), FileFormat.mp3);
    expect(_format(probeFile(_bytes([0xFF, 0xFB]), name: 'a')), FileFormat.mp3);
  });

  test('captions', () {
    expect(_format(probeFile(_bytes(utf8.encode('WEBVTT\n\n')), name: 'reel.vtt')), FileFormat.vtt);
    expect(_format(probeFile(_bytes(utf8.encode('1\n00:00:01,000 --> 00:00:02,000\nHi\n')), name: 'reel.srt')), FileFormat.srt);
  });

  test('Kindle formats are not opened', () {
    final mobi = [...List.filled(60, 0), ...ascii.encode('BOOKMOBI')];
    expect((probeFile(_bytes(mobi), name: 'dune-road.azw3') as ProbeRefused).refusal, ProbeRefusal.notSupported);
  });

  group('DRM', () {
    test('rights.xml always means a protected EPUB', () {
      expect(epubIsProtected(entries: ['mimetype', 'META-INF/rights.xml']), isTrue);
    });
    test('font obfuscation alone is not DRM', () {
      const xml = '<EncryptionMethod Algorithm="http://www.idpf.org/2008/embedding"/>';
      expect(epubIsProtected(entries: ['META-INF/encryption.xml'], encryptionXml: xml), isFalse);
    });
    test('any other encryption is', () {
      const xml = '<EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes128-cbc"/>';
      expect(epubIsProtected(entries: ['META-INF/encryption.xml'], encryptionXml: xml), isTrue);
    });
    test('a PDF with an owner password opens; a DRM handler does not', () {
      expect(pdfIsProtected('trailer << /Encrypt 9 0 R >> 9 0 obj << /Filter /Standard /V 4 >>'), isFalse);
      expect(pdfIsProtected('trailer << /Encrypt 9 0 R >> 9 0 obj << /Filter /Adobe.APS >>'), isTrue);
      expect(pdfIsProtected('trailer << /Root 1 0 R >>'), isFalse);
    });
  });
}
