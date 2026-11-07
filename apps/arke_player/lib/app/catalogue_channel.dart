import 'dart:io';

import 'package:arke_world/arke_world.dart';

/// Shared by the foreground and the scheduler's separate isolate.
final catalogueChannel = CatalogueChannel.parse(const String.fromEnvironment('ARKE_CATALOGUE_CHANNEL', defaultValue: 'production'));

Directory channelSupportDirectory(Directory support) =>
    catalogueChannel.storageFolder.isEmpty ? support : Directory('${support.path}${Platform.pathSeparator}${catalogueChannel.storageFolder}');
