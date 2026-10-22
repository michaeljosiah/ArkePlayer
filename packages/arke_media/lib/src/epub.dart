import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:xml/xml.dart';

import 'info.dart';

/// Reads an EPUB: `META-INF/container.xml` names the package document, whose metadata gives the
/// title (`dc:title`) and author (`dc:creator`), and whose manifest gives the cover — EPUB 3's
/// `properties="cover-image"`, else EPUB 2's `<meta name="cover">`. DRM is checked first
/// (`epubIsProtected`): a protected book is refused before anything else is read from it.
MediaInfo readEpub(Archive archive) {
  final names = [for (final file in archive.files) file.name];
  final encryption = _text(archive, 'META-INF/encryption.xml');
  if (epubIsProtected(entries: names, encryptionXml: encryption)) return const MediaInfo(protectedFile: true);

  final container = _text(archive, 'META-INF/container.xml');
  if (container == null) throw const UnreadableFile('no META-INF/container.xml');
  final rootfile = XmlDocument.parse(container).descendants.whereType<XmlElement>().where((element) => element.localName == 'rootfile').firstOrNull;
  final opfPath = rootfile?.getAttribute('full-path');
  final opfText = opfPath == null ? null : _text(archive, opfPath);
  if (opfPath == null || opfText == null) throw const UnreadableFile('no package document');

  final opf = XmlDocument.parse(opfText);
  String? first(String localName) =>
      opf.descendants.whereType<XmlElement>().where((element) => element.localName == localName).map((element) => element.innerText).firstOrNull;
  final items = opf.descendants.whereType<XmlElement>().where((element) => element.localName == 'item').toList();
  var coverItem = items.where((item) => (item.getAttribute('properties') ?? '').split(' ').contains('cover-image')).firstOrNull;
  if (coverItem == null) {
    final coverId = opf.descendants
        .whereType<XmlElement>()
        .where((element) => element.localName == 'meta' && element.getAttribute('name') == 'cover')
        .map((element) => element.getAttribute('content'))
        .firstOrNull;
    coverItem = items.where((item) => item.getAttribute('id') == coverId).firstOrNull;
  }

  MediaCover? cover;
  final href = coverItem?.getAttribute('href');
  if (href != null) {
    final base = opfPath.contains('/') ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1) : '';
    final bytes = _bytes(archive, _normalise('$base${Uri.decodeComponent(href)}'));
    if (bytes != null) cover = MediaCover(bytes, (coverItem!.getAttribute('media-type') ?? '').contains('png') ? 'image/png' : 'image/jpeg');
  }
  return MediaInfo(title: cleanText(first('title')), author: cleanText(first('creator')), cover: cover);
}

/// An EPUB's spine: its documents in reading order, as paths in the archive (`OEBPS/text/one.xhtml`),
/// so a place kept as a CFI — whose first step counts through the spine — finds the document it is
/// in.
List<String> readEpubSpine(Archive archive) {
  final container = _text(archive, 'META-INF/container.xml');
  if (container == null) throw const UnreadableFile('no META-INF/container.xml');
  final rootfile = XmlDocument.parse(container).descendants.whereType<XmlElement>().where((element) => element.localName == 'rootfile').firstOrNull;
  final opfPath = rootfile?.getAttribute('full-path');
  final opfText = opfPath == null ? null : _text(archive, opfPath);
  if (opfPath == null || opfText == null) throw const UnreadableFile('no package document');
  final opf = XmlDocument.parse(opfText);
  final base = opfPath.contains('/') ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1) : '';
  final hrefs = {
    for (final item in opf.descendants.whereType<XmlElement>().where((element) => element.localName == 'item'))
      ?item.getAttribute('id'): item.getAttribute('href'),
  };
  return [
    for (final itemref in opf.descendants.whereType<XmlElement>().where((element) => element.localName == 'itemref'))
      if (hrefs[itemref.getAttribute('idref')] case final href?) _normalise('$base${Uri.decodeComponent(href.split('#').first)}'),
  ];
}

String? _text(Archive archive, String name) {
  final bytes = _bytes(archive, name);
  return bytes == null ? null : utf8.decode(bytes, allowMalformed: true);
}

Uint8List? _bytes(Archive archive, String name) {
  final file = archive.find(name) ?? archive.files.where((file) => file.name.toLowerCase() == name.toLowerCase()).firstOrNull;
  return file?.readBytes();
}

/// Resolves `a/b/../c` to `a/c`, as hrefs relative to the package document may need.
String _normalise(String path) {
  final parts = <String>[];
  for (final part in path.split('/')) {
    if (part == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else if (part.isNotEmpty && part != '.') {
      parts.add(part);
    }
  }
  return parts.join('/');
}
