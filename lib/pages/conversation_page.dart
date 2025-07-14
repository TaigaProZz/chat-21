import 'package:chat_21/models/message.dart';
import 'package:chat_21/models/user.dart';
import 'package:chat_21/services/user_service.dart';
import 'package:chat_21/widgets/received_message_widget.dart';
import 'package:chat_21/widgets/sent_message_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';



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
  User? currentUserConverted;
  User? targetUser;

  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    getAuthorizedUsers().then(
      (_) async {
        await fetchTargetUser();
        await fetchCurrentUserFromFirestore();
        await fetchConversation();
      },
    );
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

    // Save the message to Firestore
    await FirebaseFirestore.instance.collection('messages').add(message.toJson());

    // Clear the input field
    _messageController.clear();

  }

  /// Fetch the conversation list from Firestore
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

  /// Get messages stream for a specific conversation
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
          Padding(padding: const EdgeInsets.only(right: 8.0),
            child: ClipOval(
              child: Image.network(
                targetUser?.avatarUrl ?? 'https://via.placeholder.com/40',
                height: 40,
                width: 40,
                errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image),
                  fit: BoxFit.cover
              ),
            )
          ),
          Text(targetUser?.bestName ?? 'Nom indisponible', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ])
        
      ),
      body: conversation.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: StreamBuilder<List<Message>>(
                  stream: getMessagesStream(conversation.first),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Aucun message.'));
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
                        await sendMessage(_messageController.text.trim());
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}
