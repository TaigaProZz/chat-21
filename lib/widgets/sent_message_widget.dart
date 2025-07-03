import 'package:flutter/material.dart';

// Ton widget Stateful pour afficher un message reçu
class SentMessageWidget extends StatelessWidget {
  const SentMessageWidget({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Text(message, style: const TextStyle(fontSize: 16.0)),
    );
  }
}


