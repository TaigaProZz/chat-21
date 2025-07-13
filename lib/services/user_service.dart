import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chat_21/models/user.dart' as app_user;
class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Utilisateur actuellement connecté
  User? get currentUser => _auth.currentUser;

   Future<User?> signIn(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  }

  Future<List<String>> fetchAuthorizedUsersUid() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('authorized_users')
        .get();

    return snapshot.docs.map((doc) => doc['uid'] as String).toList();
  }

  Future<app_user.User?> fetchTargetUser({
    required String currentUserUid,
    required List<String> authorizedUserUids,
  }) async {
    final targetUids = authorizedUserUids
        .where((uid) => uid != currentUserUid)
        .toList();

    if (targetUids.isEmpty) return null;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', whereIn: targetUids)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      return app_user.User.fromJson(data);
    }

    return null;
  }

  Future<app_user.User?> fetchCurrentUser({
    required String currentUserUid,
    required List<String> authorizedUserUids,
  }) async {
    if (!authorizedUserUids.contains(currentUserUid)) return null;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', isEqualTo: currentUserUid)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      return app_user.User.fromJson(data);
    }

    return null;
  }
}