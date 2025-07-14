import 'package:chat_21/models/user.dart';
import 'package:flutter/material.dart';

class SentMessageWidget extends StatelessWidget {
  const SentMessageWidget({
    super.key,
    required this.message,
    required this.user,
    required this.isRead,
  });

  final String message;
  final User? user;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,  
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: SelectableText(
                    message,
                    maxLines: null,
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12.0, bottom: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isRead ? Icons.done_all : Icons.done,
                        size: 16,
                        color: isRead ? Colors.blue : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isRead ? 'Lu' : 'Envoyé',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8.0, right: 4.0, top: 8.0),
          child: ClipOval(
            child: Image.network(
              user?.avatarUrl ?? 'https://via.placeholder.com/40',
              height: 40,
              width: 40,
              errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image),
                fit: BoxFit.cover
            ),
          ),
        ),
      ],
    );
  }
}
