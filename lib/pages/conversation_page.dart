// conversation_page.dart refactorisée
import 'dart:async';
import 'package:chat_21/models/message.dart';
import 'package:chat_21/models/user.dart' as user_model;
import 'package:chat_21/services/user_service.dart';
import 'package:chat_21/services/websocket_service.dart';
import 'package:chat_21/services/call_service.dart';
import 'package:chat_21/services/call_dialog_service.dart';
import 'package:chat_21/widgets/call_overlay.dart';
import 'package:chat_21/widgets/received_message_widget.dart';
import 'package:chat_21/widgets/sent_message_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key});

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  late Stream<List<Message>> _messageStream;

  List conversation = [];
  List<String> authorizedUsers = [];

  final currentUser = UserService().currentUser;
  user_model.User? currentUserConverted;
  user_model.User? targetUser;

  final TextEditingController _messageController = TextEditingController();

  // Subscriptions pour les services
  StreamSubscription? _webSocketSubscription;
  StreamSubscription? _callStateSubscription;
  StreamSubscription? _callMessageSubscription;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _webSocketSubscription?.cancel();
    _callStateSubscription?.cancel();
    _callMessageSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    // Initialiser les services
    await CallService.instance.initialize();
    await WebSocketService.instance.connect();

    // Écouter les messages WebSocket
    _webSocketSubscription = WebSocketService.instance.messageStream.listen(
      _handleWebSocketMessage,
    );

    // Écouter les changements d'état d'appel
    _callStateSubscription = CallService.instance.stateStream.listen((state) {
      if (mounted) {
        setState(() {});
      }
    });

    // Écouter les messages d'appel
    _callMessageSubscription = CallService.instance.messageStream.listen((
      message,
    ) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    });
  }

  Future<void> _initializeData() async {
    await getAuthorizedUsers();
    await fetchTargetUser();
    await fetchCurrentUserFromFirestore();
    await fetchConversation();

    if (conversation.isNotEmpty) {
      _messageStream = getMessagesStream(conversation.first);
    }
  }

  Future<void> _handleWebSocketMessage(Map<String, dynamic> data) async {
    if (!mounted) return;

    switch (data['type']) {
      case 'offer':
        await _handleIncomingCall(data['sdp'], data['from']);
        break;
      case 'answer':
        await CallService.instance.handleAnswer(data['sdp']);
        break;
      case 'candidate':
        await CallService.instance.handleCandidate(data['candidate']);
        break;
      case 'reject':
        CallService.instance.handleCallRejected();
        CallDialogService.closeDialogIfShown();
        break;
      case 'hangup':
        CallService.instance.handleCallEnded();
        CallDialogService.closeDialogIfShown();
        break;
      case 'error':
        _showSnackBar('Erreur WebSocket: ${data['error']}');
        break;
      case 'disconnected':
        _showSnackBar('Connexion WebSocket fermée');
        break;
      default:
        print('Message WebSocket inconnu: $data');
    }
  }

  Future<void> _handleIncomingCall(String sdp, String fromUid) async {
    await CallService.instance.handleOffer(sdp, fromUid);

    if (mounted) {
      final accept = await CallDialogService.showIncomingCallDialog(
        context,
        targetUser,
        fromUid,
      );

      if (accept == true) {
        await CallService.instance.acceptCall(sdp, fromUid);
      } else {
        await CallService.instance.rejectCall(fromUid);
      }
    }
  }

  Future<void> _startCall() async {
    if (targetUser != null) {
      await CallService.instance.startCall(targetUser!.id);
    }
  }

  void _hangUp() {
    CallService.instance.hangUp();
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

Widget _buildCallOverlay() {
    final callState = CallService.instance.callState;

    if (callState == CallState.idle) return const SizedBox.shrink();

    return StreamBuilder<Duration>(
      stream: CallService.instance.callDurationStream, // Nouveau stream
      builder: (context, snapshot) {
        return CallOverlay(
          avatarUrl: targetUser?.avatarUrl,
          name: targetUser?.bestName ?? 'Utilisateur inconnu',
          callStateText: _getCallStateText(callState),
          isAudioMuted: CallService.instance.isAudioMuted,
          isSpeakerOn: CallService.instance.isSpeakerOn,
          showMute: callState == CallState.connected,
          showSpeaker: callState == CallState.connected,
          showHangUp:
              callState != CallState.ended && callState != CallState.error,
          onMute: CallService.instance.toggleMute,
          onSpeaker: CallService.instance.toggleSpeaker,
          onHangUp: _hangUp,
          callDuration: callState == CallState.connected
              ? CallService.instance.formatDuration(
                  snapshot.data ?? Duration.zero,
                )
              : null,
        );
      },
    );
  }

  String _getCallStateText(CallState state) {
    switch (state) {
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
    final callState = CallService.instance.callState;

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
              color: callState == CallState.idle ? Colors.green : Colors.grey,
            ),
            onPressed: callState == CallState.idle ? _startCall : null,
            tooltip: 'Appeler',
          ),
          if (callState == CallState.connected)
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
          if (callState == CallState.idle)
            conversation.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(
                        child: StreamBuilder<List<Message>>(
                          stream: _messageStream,
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
