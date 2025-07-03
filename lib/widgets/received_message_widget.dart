import 'package:flutter/material.dart';

// Ton widget Stateful pour afficher un message reçu
class ReceivedMessageWidget extends StatelessWidget {
  const ReceivedMessageWidget({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.2;
    
    return Container(
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Text(message, style: const TextStyle(fontSize: 16.0)),
    );
  }
}
