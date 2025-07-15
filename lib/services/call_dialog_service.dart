// call_dialog_service.dart
import 'package:flutter/material.dart';
import 'package:chat_21/models/user.dart' as user_model;

class CallDialogService {
  static BuildContext? _dialogContext;
  static bool _isDialogShown = false;

  static bool get isDialogShown => _isDialogShown;

  static Future<bool?> showIncomingCallDialog(
    BuildContext context,
    user_model.User? targetUser,
    String fromUid,
  ) {
    _isDialogShown = true;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _dialogContext = dialogContext; // Stocker le context de la dialog
        return AlertDialog(
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
              onPressed: () {
                _closeDialog(false);
              },
              child: const Text("Refuser", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                _closeDialog(true);
              },
              child: const Text("Accepter"),
            ),
          ],
        );
      },
    ).then((result) {
      _isDialogShown = false;
      _dialogContext = null;
      return result;
    });
  }

  static void _closeDialog(bool? result) {
    if (_dialogContext != null) {
      Navigator.pop(_dialogContext!, result);
      _isDialogShown = false;
      _dialogContext = null;
    }
  }

  // Méthode pour fermer la dialog depuis l'extérieur
  static void closeDialogIfShown([bool? result]) {
    if (_isDialogShown && _dialogContext != null) {
      _closeDialog(result ?? false);
    }
  }
}
