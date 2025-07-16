// websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WebSocketService {
  static WebSocketService? _instance;
  static WebSocketService get instance => _instance ??= WebSocketService._();

  WebSocketService._();

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  String? _myUid;

  // Stream controller pour les messages WebSocket
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  bool get isConnected => _channel != null;
  String? get myUid => _myUid;

  Future<void> connect() async {
    if (_channel != null) {
      await disconnect();
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final token = await user.getIdToken();
      _myUid = user.uid;

      _channel = WebSocketChannel.connect(
        Uri.parse('wss://ws.chat.taigaprozz.ovh/?token=$token'),
      );

      _channelSubscription = _channel!.stream.listen(
        (event) async {
          await _handleMessage(event);
        },
        onError: (error) {
          print('Erreur WebSocket: $error');
          _messageController.add({'type': 'error', 'error': error.toString()});
        },
        onDone: () {
          print('WebSocket fermé');
          _messageController.add({'type': 'disconnected'});
        },
      );
    } catch (e) {
      print('Erreur connexion WebSocket: $e');
      _messageController.add({'type': 'error', 'error': e.toString()});
    }
  }

  Future<void> _handleMessage(dynamic event) async {
    String messageStr;

    if (event is String) {
      messageStr = event;
    } else if (event is Uint8List) {
      messageStr = String.fromCharCodes(event);
    } else {
      print('Type de message non supporté: ${event.runtimeType}');
      return;
    }

    try {
      final data = jsonDecode(messageStr);
      _messageController.add(data);
    } catch (e) {
      print('Erreur décodage JSON: $e');
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  Future<void> disconnect() async {
    await _channelSubscription?.cancel();
    _channelSubscription = null;

    _channel?.sink.close();
    _channel = null;

    _myUid = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
