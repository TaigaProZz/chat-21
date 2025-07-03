import 'package:chat_21/providers/theme_provider.dart';
import 'package:chat_21/services/user_service.dart';
import 'package:chat_21/widgets/received_message_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});


  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    User? user = UserService().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.displayName ?? 'Bienvenue'),
        actions: [
          IconButton(
            icon: user?.photoURL != null
                ? CircleAvatar(
                    backgroundImage: NetworkImage(user!.photoURL!),
                  )
                : const Icon(Icons.account_circle),
            onPressed: () {
              // Logique de déconnexion ici
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 20),

            SwitchListTile(
              title: const Text("Mode sombre"),
              value: isDark,
              onChanged: (value) {
                themeProvider.toggleTheme(value);
              },
            ),
              
          ],

        ),
        
        
      ),
    );
  }
}
