import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// What a hosted player tells the Player. The module posts JSON on the `ArkePlayer` channel.
sealed class PlayerEvent {
  const PlayerEvent();

  static PlayerEvent? parse(String message) {
    final Object? json;
    try {
      json = jsonDecode(message);
    } on FormatException {
      return null;
    }
    if (json is! Map<String, Object?>) return null;
    return switch (json['type']) {
      'place' => PlacePlayerEvent(json['place']),
      'ended' => const EndedPlayerEvent(),
      'close' => const ClosePlayerEvent(),
      _ => null,
    };
  }
}

/// Where the viewer is, as the module keeps it: `{ sceneId, positionSec, route }`, a chapter and
/// a time, or a scene and a beat. The Player stores it on this device only (Studio 156f).
class PlacePlayerEvent extends PlayerEvent {
  const PlacePlayerEvent(this.place);
  final Object? place;
}

class EndedPlayerEvent extends PlayerEvent {
  const EndedPlayerEvent();
}

/// The module's own ⌄ was pressed.
class ClosePlayerEvent extends PlayerEvent {
  const ClosePlayerEvent();
}

/// Hosts one of the Studio's framework-free player modules — the same `player.html` a package
/// carries — in a web view, so what plays in a browser plays the same here (Arke Player P3
/// rule 1, docs/decisions/0001). The Player adds only its close and, around this widget, the
/// phone's media session.
class WebPlayerHost extends StatefulWidget {
  const WebPlayerHost({required this.playerHtml, required this.onEvent, this.place, super.key});

  /// The package's `player.html`, already verified and in the Player's own storage.
  final File playerHtml;

  /// The place this device kept, handed back to the module when it is ready.
  final Object? place;

  final void Function(PlayerEvent event) onEvent;

  @override
  State<WebPlayerHost> createState() => _WebPlayerHostState();
}

class _WebPlayerHostState extends State<WebPlayerHost> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'ArkePlayer',
        onMessageReceived: (message) {
          final event = PlayerEvent.parse(message.message);
          if (event != null) widget.onEvent(event);
        },
      )
      // A package is local and self-contained; nothing it shows may navigate the view elsewhere.
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => request.url.startsWith('file:') ? NavigationDecision.navigate : NavigationDecision.prevent,
          onPageFinished: (_) => _restorePlace(),
        ),
      )
      ..loadFile(widget.playerHtml.path);
  }

  Future<void> _restorePlace() async {
    final place = widget.place;
    if (place == null) return;
    await _controller.runJavaScript('window.arkePlayer?.restore(${jsonEncode(place)})');
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
