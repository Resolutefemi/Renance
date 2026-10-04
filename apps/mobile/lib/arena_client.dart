/// Arena WebSocket client, the app half of the multiplayer hub
/// (apps/study-api/internal/arena). One authenticated socket per arena
/// session: queue / host / join / challenge → matched → question /
/// result… → over. Frames mirror internal/arena/message.go exactly.
///
/// Transport is dart:io's WebSocket - no new dependency, the same
/// ?token= contract the web client uses (the hub's CheckOrigin is open
/// and the token rides the URL).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config.dart';

class ArenaSocket {
  ArenaSocket({required void Function(Map<String, dynamic> frame) onFrame, this.onDown})
      : _onFrame = onFrame;

  /// The frame consumer. The arena lobby owns it; the live match screen
  /// swaps in its own handler for the duel and restores the owner's on
  /// dispose (one listener at a time, by design).
  void Function(Map<String, dynamic> frame) _onFrame;
  set onFrame(void Function(Map<String, dynamic> frame) handler) => _onFrame = handler;
  final VoidCallback? onDown;

  WebSocket? _ws;
  final List<Map<String, dynamic>> _outbox = <Map<String, dynamic>>[];
  bool _closedByUs = false;

  /// Connects and flushes anything queued before the handshake.
  Future<void> connect(String token) async {
    final String base =
        apiBaseUrl.replaceFirst(RegExp('^http'), 'ws');
    final String url =
        '$base/arena/ws?token=${Uri.encodeComponent(token)}';
    try {
      final WebSocket ws = await WebSocket.connect(url);
      _ws = ws;
      ws.listen(
        (dynamic data) {
          try {
            final dynamic decoded = jsonDecode(data.toString());
            if (decoded is Map<String, dynamic>) _onFrame(decoded);
          } catch (_) {
            // Malformed frame: ignore, the hub never sends one.
          }
        },
        onError: (Object _) {
          if (!_closedByUs) onDown?.call();
        },
        onDone: () {
          if (!_closedByUs) onDown?.call();
        },
        cancelOnError: true,
      );
      for (final Map<String, dynamic> frame in _outbox) {
        ws.add(jsonEncode(frame));
      }
      _outbox.clear();
    } catch (_) {
      onDown?.call();
    }
  }

  /// Safe before the socket opens: frames queue until the handshake.
  void send(Map<String, dynamic> frame) {
    final WebSocket? ws = _ws;
    if (ws != null && ws.readyState == WebSocket.open) {
      ws.add(jsonEncode(frame));
    } else {
      _outbox.add(frame);
    }
  }

  void close() {
    _closedByUs = true;
    _ws?.close();
    _ws = null;
  }
}
