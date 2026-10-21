import 'dart:convert';
import 'dart:typed_data';

/// What a person can add beside an Arke package (Arke Player P7 rule 1), and the package itself.
enum FileFormat {
  arkePackage('Arke package'),
  epub('EPUB'),
  pdf('PDF'),
  cbz('CBZ'),
  m4b('M4B'),
  m4a('M4A'),
  mp3('MP3'),
  mp4('MP4'),
  mov('MOV'),
  srt('SRT'),
  vtt('VTT'),

  /// A world's narration as a listening document (SPEC-058 R-10): a file a chapter with its
  /// pictures and phrases. It arrives only inside a world package, never added on its own.
  listening('Audiobook');

  const FileFormat(this.label);

  /// The format's name as the Add sheet and Library show it.
  final String label;

  /// Captions travel beside a video of the same name; they are never added on their own.
  bool get isSidecar => this == srt || this == vtt;
}

/// Why a file was refused, each one clause on screen (P7 rule 3).
enum ProbeRefusal {
  /// `Not a supported format` — MOBI, AZW, DOCX, plain text, anything unrecognised.
  notSupported,

  /// `Can't open this file` — it claims a format and is not a well-formed one.
  cannotOpen,

  /// `Protected file` — DRM. Store-locked books, documents and audio are never opened.
  protectedFile,
}

/// What looking at a file's first bytes concluded: a format, or a refusal.
sealed class Probe {
  const Probe();
}

class ProbeFormat extends Probe {
  const ProbeFormat(this.format);
  final FileFormat format;
}

class ProbeRefused extends Probe {
  const ProbeRefused(this.refusal, this.detail);
  final ProbeRefusal refusal;
  final String detail;
}

const _zip = [0x50, 0x4B, 0x03, 0x04];
const _epubMimetype = 'mimetypeapplication/epub+zip';

/// Recognises a file from its first bytes ([head], at least the first 128 when the file is that
/// long) and its [name]. Bytes decide where they can; the name decides only between containers
/// that look alike from the outside (a ZIP that is an Arke package or a comic). A ZIP's contents
/// are confirmed later, when it is opened; this only says which reader should try.
Probe probeFile(Uint8List head, {required String name}) {
  final extension = name.contains('.') ? name.substring(name.lastIndexOf('.') + 1).toLowerCase() : '';

  if (_startsWith(head, ascii.encode('%PDF-'))) return const ProbeFormat(FileFormat.pdf);

  if (head.length >= 68 && ascii.decode(head.sublist(60, 68), allowInvalid: true) == 'BOOKMOBI') {
    return const ProbeRefused(ProbeRefusal.notSupported, 'MOBI or AZW');
  }

  if (_startsWith(head, _zip)) {
    // An EPUB's first entry is `mimetype`, stored uncompressed, so its content sits right after
    // the local header's name — the OCF rule that makes this check reliable.
    if (head.length >= 30 + _epubMimetype.length && ascii.decode(head.sublist(30, 30 + _epubMimetype.length), allowInvalid: true) == _epubMimetype) {
      return const ProbeFormat(FileFormat.epub);
    }
    return switch (extension) {
      'arke' || 'zip' => const ProbeFormat(FileFormat.arkePackage),
      'cbz' => const ProbeFormat(FileFormat.cbz),
      'epub' => const ProbeRefused(ProbeRefusal.cannotOpen, 'an EPUB without its mimetype entry'),
      _ => ProbeRefused(ProbeRefusal.notSupported, extension.isEmpty ? 'a ZIP' : extension.toUpperCase()),
    };
  }

  // ISO base media (MP4, M4A, M4B, MOV): a size, then `ftyp`, then the major brand.
  if (head.length >= 12 && ascii.decode(head.sublist(4, 8), allowInvalid: true) == 'ftyp') {
    final brand = ascii.decode(head.sublist(8, 12), allowInvalid: true);
    return switch (brand) {
      'M4B ' => const ProbeFormat(FileFormat.m4b),
      'M4A ' => const ProbeFormat(FileFormat.m4a),
      'qt  ' => const ProbeFormat(FileFormat.mov),
      // A FairPlay-protected song or book carries its own brand.
      'M4P ' => const ProbeRefused(ProbeRefusal.protectedFile, 'FairPlay'),
      _ => ProbeFormat(
        extension == 'm4b'
            ? FileFormat.m4b
            : extension == 'm4a'
            ? FileFormat.m4a
            : FileFormat.mp4,
      ),
    };
  }

  if (_startsWith(head, ascii.encode('ID3')) || (head.length >= 2 && head[0] == 0xFF && (head[1] & 0xE0) == 0xE0)) {
    return const ProbeFormat(FileFormat.mp3);
  }

  final text = utf8.decode(head, allowMalformed: true).replaceFirst('﻿', '');
  if (text.startsWith('WEBVTT')) return const ProbeFormat(FileFormat.vtt);
  if (extension == 'srt' && RegExp(r'^\s*\d+\s*\r?\n\d{2}:\d{2}:\d{2},\d{3} --> ').hasMatch(text)) {
    return const ProbeFormat(FileFormat.srt);
  }

  return ProbeRefused(ProbeRefusal.notSupported, extension.isEmpty ? 'unknown' : extension.toUpperCase());
}

/// Whether an EPUB is store-locked. `META-INF/rights.xml` always means DRM. `encryption.xml`
/// alone does not: publishers obfuscate embedded fonts with it, so only an algorithm other than
/// font obfuscation counts.
bool epubIsProtected({required Iterable<String> entries, String? encryptionXml}) {
  final names = entries.map((entry) => entry.toLowerCase()).toSet();
  if (names.contains('meta-inf/rights.xml')) return true;
  if (encryptionXml == null) return false;
  const fontObfuscation = ['http://www.idpf.org/2008/embedding', 'http://ns.adobe.com/pdf/enc#RC'];
  final algorithms = RegExp(r'Algorithm="([^"]+)"').allMatches(encryptionXml).map((match) => match.group(1)!);
  return algorithms.any((algorithm) => !fontObfuscation.contains(algorithm));
}

/// Whether a PDF is store-locked. [encryption] is the text of the trailer and of the dictionary
/// its `/Encrypt` refers to. A PDF with only an owner password uses the `Standard` handler and
/// opens; any other handler (Adobe, FileOpen and the like) is DRM and is refused.
bool pdfIsProtected(String encryption) {
  if (!encryption.contains('/Encrypt')) return false;
  return !RegExp(r'/Filter\s*/Standard\b').hasMatch(encryption);
}

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}
