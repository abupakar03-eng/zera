import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_constants.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  /// Providers subscribe to this stream to receive real-time events.
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  bool _isConnected = false;
  bool _disposed = false;
  String? _token;

  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  bool get isConnected => _isConnected;

  void connect(String token) {
    _token = token;
    _reconnectAttempts = 0;
    _doConnect();
  }

  void _doConnect() {
    if (_disposed || _token == null) return;

    final wsUrl = _buildWsUrl(_token!);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _subscription = _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
      _isConnected = true;
      _reconnectAttempts = 0;
      if (kDebugMode) debugPrint('[WS] Connected to $wsUrl');
    } catch (e) {
      if (kDebugMode) debugPrint('[WS] Connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      _eventController.add(map);
    } catch (e) {
      if (kDebugMode) debugPrint('[WS] Parse error: $e');
    }
  }

  void _onError(Object error) {
    if (kDebugMode) debugPrint('[WS] Error: $error');
    _isConnected = false;
    _scheduleReconnect();
  }

  void _onDone() {
    if (kDebugMode) debugPrint('[WS] Connection closed');
    _isConnected = false;
    if (!_disposed) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectAttempts++;
    // Quadratic backoff: 1s, 4s, 9s, ... capped at 30s
    final delaySecs = (_reconnectAttempts * _reconnectAttempts).clamp(1, 30);
    if (kDebugMode) {
      debugPrint('[WS] Reconnecting in ${delaySecs}s (attempt $_reconnectAttempts)');
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySecs), _doConnect);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _token = null;
    _reconnectAttempts = 0;
    if (kDebugMode) debugPrint('[WS] Disconnected');
  }

  static String _buildWsUrl(String token) {
    // Always use wss:// (encrypted WebSocket) — never ws://
    final base = ApiConstants.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'wss://');
    return '$base/ws?token=${Uri.encodeComponent(token)}';
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _eventController.close();
  }
}
