import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:chat_21/models/message.dart';
import 'package:chat_21/models/user.dart' as user_model;
import 'package:chat_21/services/user_service.dart';
import 'package:chat_21/widgets/call_overlay.dart';
import 'package:chat_21/widgets/received_message_widget.dart';
import 'package:chat_21/widgets/sent_message_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum CallState { idle, calling, ringing, connected, ended, error }

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key});

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  List conversation = [];
  List messages = [];
  List<String> authorizedUsers = [];

  final currentUser = UserService().currentUser;
  user_model.User? currentUserConverted;
  user_model.User? targetUser;

  final TextEditingController _messageController = TextEditingController();

  // --- WebRTC variables ---
  late RTCVideoRenderer _remoteRenderer;
  StreamSubscription? _channelSubscription;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  WebSocketChannel? _channel;
  String? _myUid;
  CallState _callState = CallState.idle;
  String? _callerUid;
  Timer? _callTimer;
  int _callDuration = 0;
  bool _isAudioMuted = false;
  bool _isSpeakerOn = false;

  // Configuration WebRTC améliorée
  final Map<String, dynamic> _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  final Map<String, dynamic> _mediaConstraints = {
    'audio': {
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
    },
    'video': false,
  };

  @override
  void initState() {
    super.initState();
    _initRenderer();
    getAuthorizedUsers().then((_) async {
      await fetchTargetUser();
      await fetchCurrentUserFromFirestore();
      await fetchConversation();
      await _connectToWebSocket();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _remoteRenderer.dispose();
    _cleanupCall();
    _channel?.sink.close();
    _channelSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initRenderer() async {
    _remoteRenderer = RTCVideoRenderer();
    await _remoteRenderer.initialize();
  }

  Future<void> _connectToWebSocket() async {
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
          await _handleWebSocketMessage(event);
        },
        onError: (error) {
          print('Erreur WebSocket: $error');
          _setState(CallState.error);
        },
        onDone: () {
          print('WebSocket fermé');
          _setState(CallState.ended);
        },
      );
    } catch (e) {
      print('Erreur connexion WebSocket: $e');
      _setState(CallState.error);
    }
  }

  Future<void> _handleWebSocketMessage(dynamic event) async {
    // Vérifier si le widget est encore monté
    if (!mounted) return;

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

      // Vérifier à nouveau si le widget est monté avant de traiter
      if (!mounted) return;

      switch (data['type']) {
        case 'offer':
          await _onOffer(data['sdp'], data['from']);
          break;
        case 'answer':
          await _onAnswer(data['sdp']);
          break;
        case 'candidate':
          await _onCandidate(data['candidate']);
          break;
        case 'reject':
          _onCallRejected();
          break;
        case 'hangup':
          _onCallEnded();
          break;
        default:
          print('Message inconnu reçu: $data');
      }
    } catch (e) {
      print('Erreur décodage JSON: $e');
    }
  }

  Future<void> _createPeerConnection() async {
    try {
      _peerConnection = await createPeerConnection(_rtcConfig);

      // Obtenir le flux audio local
      _localStream = await navigator.mediaDevices.getUserMedia(
        _mediaConstraints,
      );

      // Ajouter les tracks au peer connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Gestion des candidats ICE
      _peerConnection!.onIceCandidate = (candidate) {
        if (candidate != null) {
          _sendMessage({
            'type': 'candidate',
            'candidate': candidate.toMap(),
            'to': targetUser?.id,
          });
        }
      };

      // Gestion du flux distant
      _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty && mounted) {
          setState(() {
            _remoteRenderer.srcObject = event.streams[0];
            _callState = CallState.connected;
          });
          _startCallTimer();
        }
      };

      // Gestion des états de connexion
      _peerConnection!.onConnectionState = (state) {
        print('État de connexion: $state');
        if (!mounted) return;

        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            _setState(CallState.connected);
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
            _onCallEnded();
            break;
          default:
            break;
        }
      };

      // Gestion des erreurs ICE
      _peerConnection!.onIceConnectionState = (state) {
        print('État ICE: $state');
        if (!mounted) return;

        if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          _setState(CallState.error);
        }
      };
    } catch (e) {
      print('Erreur création peer connection: $e');
      _setState(CallState.error);
    }
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  Future<void> _startCall() async {
    if (_callState != CallState.idle) return;

    try {
      _setState(CallState.calling);
      await _createPeerConnection();

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      _sendMessage({
        'type': 'offer',
        'sdp': offer.sdp,
        'from': _myUid,
        'to': targetUser?.id,
      });
    } catch (e) {
      print('Erreur démarrage appel: $e');
      _setState(CallState.error);
    }
  }

  Future<void> _onOffer(String sdp, String fromUid) async {
    print('Appel entrant de $fromUid');

    // Rejeter si déjà en appel
    if (_callState != CallState.idle) {
      _sendMessage({'type': 'reject', 'from': _myUid, 'to': fromUid});
      return;
    }

    _setState(CallState.ringing);
    _callerUid = fromUid;

    if (mounted ) {
      final accept = await _showIncomingCallDialog(fromUid);

       if (accept != true) {
        _sendMessage({'type': 'reject', 'from': _myUid, 'to': fromUid});
        _setState(CallState.idle);
        return;
      }
    };

    try {
      await _createPeerConnection();
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, 'offer'),
      );

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      _sendMessage({'type': 'answer', 'sdp': answer.sdp, 'to': fromUid});
    } catch (e) {
      print('Erreur réponse appel: $e');
      _setState(CallState.error);
    }
  }

  Future<bool?> _showIncomingCallDialog(String fromUid) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Appel entrant"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_in_talk, size: 48, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              "${targetUser?.bestName ?? 'Utilisateur inconnu'} vous appelle",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Refuser", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Accepter"),
          ),
        ],
      ),
    );
  }

  Future<void> _onAnswer(String sdp) async {
    try {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, 'answer'),
      );
    } catch (e) {
      print('Erreur traitement réponse: $e');
      _setState(CallState.error);
    }
  }

  Future<void> _onCandidate(dynamic candidateMap) async {
    try {
      final candidate = RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );
      await _peerConnection?.addCandidate(candidate);
    } catch (e) {
      print('Erreur ajout candidat: $e');
    }
  }

  void _onCallRejected() {
    if (!mounted) return;
    _setState(CallState.ended);
    _showSnackBar('Appel refusé');
  }

  void _onCallEnded() {
    if (!mounted) return;
    if (currentUser == null) return;
    _setState(CallState.ended);
    _showSnackBar('Appel terminé');
  }

  void _hangUp() {
    _sendMessage({'type': 'hangup', 'from': _myUid, 'to': targetUser?.id});
    _setState(CallState.ended);
  }

  void _setState(CallState newState) {
    if (_callState == newState || !mounted) return;

    setState(() {
      _callState = newState;
    });

    if (newState == CallState.ended || newState == CallState.error) {
      _cleanupCall();
      // Retour automatique à la conversation après 2 secondes
      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _callState = CallState.idle;
          });
        }
      });
    }
  }

  void _cleanupCall() {
    _callTimer?.cancel();
    _callTimer = null;
    _callDuration = 0;
    _peerConnection?.close();
    _peerConnection = null;
    _localStream?.dispose();
    _localStream = null;
    _remoteRenderer.srcObject = null;
    _callerUid = null;
    _isAudioMuted = false;
    _isSpeakerOn = false;
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  void _toggleMute() {
    if (_localStream != null && mounted) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;
      setState(() {
        _isAudioMuted = !audioTrack.enabled;
      });
    }
  }

  void _toggleSpeaker() {
    if (!mounted) return;
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    // Implémentation spécifique à la plateforme pour le haut-parleur
    Helper.setSpeakerphoneOn(_isSpeakerOn);
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildCallOverlay() {
    if (_callState == CallState.idle) return const SizedBox.shrink();

    return CallOverlay(
      avatarUrl: targetUser?.avatarUrl,
      name: targetUser?.bestName ?? 'Utilisateur inconnu',
      callStateText: _getCallStateText(),
      isAudioMuted: _isAudioMuted,
      isSpeakerOn: _isSpeakerOn,
      showMute: _callState == CallState.connected,
      showSpeaker: _callState == CallState.connected,
      showHangUp:
          _callState != CallState.ended && _callState != CallState.error,
      onMute: _toggleMute,
      onSpeaker: _toggleSpeaker,
      onHangUp: _hangUp,
      callDuration: _callState == CallState.connected
          ? _formatDuration(_callDuration)
          : null,
    );
  }
  String _getCallStateText() {
    switch (_callState) {
      case CallState.calling:
        return 'Appel en cours...';
      case CallState.ringing:
        return 'Appel entrant...';
      case CallState.connected:
        return 'En conversation';
      case CallState.ended:
        return 'Appel terminé';
      case CallState.error:
        return 'Erreur d\'appel';
      default:
        return '';
    }
  }

  // --- Le reste de votre code (messages, etc) reste identique ---

  Future<void> fetchTargetUser() async {
    if (currentUser != null && authorizedUsers.isNotEmpty) {
      final fetchedTargetUser = await UserService().fetchTargetUser(
        currentUserUid: currentUser!.uid,
        authorizedUserUids: authorizedUsers,
      );

      if (fetchedTargetUser != null && mounted) {
        setState(() {
          targetUser = fetchedTargetUser;
        });
      }
    }
  }

  Future<void> fetchCurrentUserFromFirestore() async {
    if (currentUser != null && authorizedUsers.isNotEmpty) {
      final fetchedUser = await UserService().fetchCurrentUser(
        currentUserUid: currentUser!.uid,
        authorizedUserUids: authorizedUsers,
      );

      if (fetchedUser != null && mounted) {
        setState(() {
          currentUserConverted = fetchedUser;
        });
      }
    }
  }

  Future<void> sendMessage(String content) async {
    if (content.isEmpty || targetUser == null) return;

    final message = Message(
      content: content,
      senderId: currentUser!.uid,
      receiverId: targetUser!.id,
      conversationId: conversation.isNotEmpty ? conversation.first : '',
      timestamp: Timestamp.now(),
    );

    await FirebaseFirestore.instance
        .collection('messages')
        .add(message.toJson());
    _messageController.clear();
  }

  Future<void> fetchConversation() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('conversation')
        .get();

    if (snapshot.docs.isNotEmpty && mounted) {
      setState(() {
        conversation = snapshot.docs.map((doc) => doc.id).toList();
      });
    }
  }

  Stream<List<Message>> getMessagesStream(String conversationId) {
    return FirebaseFirestore.instance
        .collection('messages')
        .where('conversation_id', isEqualTo: conversationId)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Message.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> getAuthorizedUsers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('authorized_users')
        .get();

    if (snapshot.docs.isNotEmpty) {
      authorizedUsers = snapshot.docs.map((doc) => doc.id).toList();
    }
  }

  Future<void> markMessagesAsRead(List<Message> messages) async {
    final unreadMessages = messages
        .where((m) => !m.isRead && m.receiverId == currentUser?.uid)
        .toList();

    if (unreadMessages.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();

    for (var message in unreadMessages) {
      if (message.id != null) {
        final docRef = FirebaseFirestore.instance
            .collection('messages')
            .doc(message.id);
        batch.update(docRef, {'is_read': true});
      }
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ClipOval(
                child: Image.network(
                  targetUser?.avatarUrl ?? 'https://via.placeholder.com/40',
                  height: 40,
                  width: 40,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Text(
              targetUser?.bestName ?? 'Nom indisponible',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.phone,
              color: _callState == CallState.idle ? Colors.green : Colors.grey,
            ),
            onPressed: _callState == CallState.idle ? _startCall : null,
            tooltip: 'Appeler',
          ),
          if (_callState == CallState.connected)
            IconButton(
              icon: const Icon(Icons.call_end),
              color: Colors.red,
              tooltip: 'Raccrocher',
              onPressed: _hangUp,
            ),
        ],
      ),
      body: Stack(
        children: [
          // Interface de chat normale
          if (_callState == CallState.idle)
            conversation.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(
                        child: StreamBuilder<List<Message>>(
                          stream: getMessagesStream(conversation.first),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Center(
                                child: Text('Aucun message.'),
                              );
                            }

                            final messages = snapshot.data!;

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                markMessagesAsRead(snapshot.data!);
                              }
                            });

                            return ListView.builder(
                              padding: const EdgeInsets.all(8.0),
                              reverse: true,
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final message = messages[index];
                                final isSentByMe =
                                    message.senderId == currentUser?.uid;

                                return isSentByMe
                                    ? SentMessageWidget(
                                        message: message.content,
                                        user: currentUserConverted,
                                        isRead: message.isRead,
                                      )
                                    : ReceivedMessageWidget(
                                        message: message.content,
                                        targetUser: targetUser,
                                      );
                              },
                            );
                          },
                        ),
                      ),
                      // Zone d'envoi
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                decoration: const InputDecoration(
                                  hintText: 'Écrire un message...',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send),
                              color: Colors.blue,
                              onPressed: () async {
                                await sendMessage(
                                  _messageController.text.trim(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          _buildCallOverlay(),
        ],
      ),
    );
  }
}
