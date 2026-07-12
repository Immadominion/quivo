import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

enum LinkState { idle, connecting, open, closed }

/// Thin transport over the JSON-WS gateway (services/realtime/src/gateway.ts).
/// Speaks maps in both directions; owns reconnect/backoff. The game controller sits on top.
class GatewayService {
  GatewayService(this.url);
  final String url;

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _link = StreamController<LinkState>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messages.stream;
  Stream<LinkState> get link => _link.stream;

  Timer? _heartbeat;
  bool _closedByUs = false;

  Future<void> connect() async {
    _closedByUs = false;
    _link.add(LinkState.connecting);
    try {
      final ch = WebSocketChannel.connect(Uri.parse(url));
      await ch.ready;
      _ch = ch;
      _link.add(LinkState.open);
      _sub = ch.stream.listen(_onData, onError: (_) => _onDisconnect(), onDone: _onDisconnect);
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) => send({'t': 'ping'}));
    } catch (_) {
      _onDisconnect();
    }
  }

  void _onData(dynamic raw) {
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is Map<String, dynamic>) _messages.add(decoded);
    } catch (_) {/* ignore malformed frame */}
  }

  void _onDisconnect() {
    _heartbeat?.cancel();
    _sub?.cancel();
    _sub = null;
    _ch = null;
    if (_closedByUs) {
      _link.add(LinkState.closed);
    } else {
      _link.add(LinkState.connecting); // controller decides whether to retry
      _link.add(LinkState.closed);
    }
  }

  void send(Map<String, dynamic> msg) {
    final ch = _ch;
    if (ch == null) return;
    try {
      ch.sink.add(jsonEncode(msg));
    } catch (_) {/* dropped; reconnect will resync */}
  }

  Future<void> close() async {
    _closedByUs = true;
    _heartbeat?.cancel();
    await _sub?.cancel();
    await _ch?.sink.close(ws_status.normalClosure);
    _ch = null;
    if (!_link.isClosed) _link.add(LinkState.closed);
  }

  Future<void> dispose() async {
    await close();
    await _messages.close();
    await _link.close();
  }
}
