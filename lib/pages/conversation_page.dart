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
  List<Message> messages = [];
  List<String> authorizedUsers = [];
  final currentUser = UserService().currentUser;

  @override
  void initState() {
    super.initState();
    messages = getMockMessages();
    Future<String> targetUserId = fetchAuthorizedUsers();
    targetUserId.then((userId) {
      print('Target User ID: $userId');
      // Vous pouvez utiliser userId pour charger des messages spécifiques
    }).catchError((error) {
      print('Erreur lors de la récupération des utilisateurs autorisés : $error');
    });

  }

  Future<String> fetchAuthorizedUsers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('authorized_users')
        .get();

    setState(() {
      authorizedUsers = snapshot.docs.map((doc) => doc['uid'] as String).toList();
    });

    authorizedUsers.remove(currentUser?.uid);

    return authorizedUsers.first;
  }

  @override
  Widget build(BuildContext context) {
    final myUserMock = getMockMyUser();
    final userTargetUsername = "userTargetMock.username"; // À adapter

    return Scaffold(
      appBar: AppBar(title: Text(userTargetUsername)),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          final isSentByMe = message.senderId == myUserMock.id;

          return isSentByMe
              ? SentMessageWidget(message: message.content)
              : ReceivedMessageWidget(message: message.content);
        },
      ),
    );
  }
}


List<Message> getMockMessages() {
  final jsonData = [
    {"id": "1", "content": "Salut !", "senderId": "2", "receiverId": "1", "conversationId": "1", "timestamp": "2023-10-01T12:00:00Z"},
    {"id": "2", "content": "Bonjour ! Comment ça va ?", "senderId": "1", "receiverId": "2", "conversationId": "1", "timestamp": "2023-10-01T12:01:00Z"},
    {"id": "3", "content": "Ça va bien, merci ! Et toi ?", "senderId": "2", "receiverId": "1", "conversationId": "1", "timestamp": "2023-10-01T12:02:00Z"},
    {"id": "4", "content": "Moi aussi, ça va bien !", "senderId": "1", "receiverId": "2", "conversationId": "1", "timestamp": "2023-10-01T12:03:00Z"},
    {"id": "5", "content": "Super ! Tu as des projets pour ce week-end ?", "senderId": "2", "receiverId": "1", "conversationId": "1", "timestamp": "2023-10-01T12:04:00Z"},
  ];

  return jsonData.map((json) => Message.fromJson(json)).toList();
}


User getMockMyUser() {
  return User(
    id: '1',
    username: 'user2',
    email: 'a@a.c',
    avatarUrl: 'https://example.com/avatar2.png',
    bio: 'This is user 2 bio',
  );
}

Future<QuerySnapshot<Map<String, dynamic>>> getAuthorizedUsers() async {
  return await FirebaseFirestore.instance.collection('authorized_users').get();
}

void printAuthorizedUsers() async {
  final users = await FirebaseFirestore.instance
      .collection('authorized_users')
      .get();
  for (var user in users.docs) {
    print('Authorized User: ${user.data()}');
  }
}
