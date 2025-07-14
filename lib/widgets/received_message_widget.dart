import 'package:chat_21/models/user.dart';
import 'package:flutter/material.dart';

// Ton widget Stateful pour afficher un message reçu
class ReceivedMessageWidget extends StatelessWidget {
  const ReceivedMessageWidget({
    super.key,
    required this.message,
    required this.targetUser,
  });

  final String message;
  final User? targetUser;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, right: 4.0, top: 8.0),
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
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            child: Container(
              padding: const EdgeInsets.all(8.0),
              margin: const EdgeInsets.symmetric(
                vertical: 4.0,
                horizontal: 8.0,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: SelectableText(
                message,
                maxLines: null,
                style: TextStyle(
                  fontSize: 16.0,
                  color: Theme.of(context).colorScheme.onSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
