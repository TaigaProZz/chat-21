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
  final UserService _userService = UserService();
  List<String> authorizedUsers = [];
  List conversation = [];
  List messages = [];

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

    _userService.fetchAuthorizedUsersUid().then((uids) {
      setState(() {
        authorizedUsers = uids;
      });

      if (uids.contains(currentUser?.uid)) {
        fetchTargetUser();
        fetchCurrentUserFromFirestore();
        fetchConversation();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are not authorized to view this conversation.'),
          ),
        );
      }
    });
  }

  Future<void> fetchTargetUser() async {
    if (currentUser != null && authorizedUsers.isNotEmpty) {

      final fetchedTargetUser = await UserService().fetchTargetUser(
        currentUserUid: currentUser!.uid,
        authorizedUserUids: authorizedUsers,
      );

      if (fetchedTargetUser != null) {
        setState(() {
          targetUser = fetchedTargetUser;
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Target user not found.')));
      }
    }
  }

  Future<void> fetchCurrentUserFromFirestore() async {
    if (currentUser != null && authorizedUsers.isNotEmpty) {
      final fetchedUser = await UserService().fetchCurrentUser(
        currentUserUid: currentUser!.uid,
        authorizedUserUids: authorizedUsers,
      );

      if (fetchedUser != null) {
        setState(() {
          currentUserConverted = fetchedUser;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current user not found.')),
        );
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

    if (snapshot.docs.isNotEmpty) {
      setState(() {
        conversation = snapshot.docs.map((doc) => doc.id).toList();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucune conversation trouvée.")),
      );
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
        .map((snapshot) =>
          snapshot.docs.map((doc) => Message.fromJson(doc.data())).toList(),
        );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Conversation with ${targetUser?.displayName ?? 'Unknown'}',
        ),
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

                    for (final message in messages) {
                        final isUnread =
                            !message.isRead &&
                            message.receiverId == currentUser?.uid;

                        if (isUnread) {
                          FirebaseFirestore.instance
                              .collection('messages')
                              .where(
                                'conversation_id',
                                isEqualTo: conversation.first,
                              )
                              .where('timestamp', isEqualTo: message.timestamp)
                              .limit(1)
                              .get()
                              .then((snapshot) {
                                if (snapshot.docs.isNotEmpty) {
                                  FirebaseFirestore.instance
                                      .collection('messages')
                                      .doc(snapshot.docs.first.id)
                                      .update({'is_read': true});
                                }
                              });
                        }
                      }

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

Future<QuerySnapshot<Map<String, dynamic>>> getAuthorizedUsers() async {
  return await FirebaseFirestore.instance.collection('authorized_users').get();
}
