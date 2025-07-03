class User {
  final String id;
  final String username;
  final String email;
  final String? avatarUrl;
  final String? bio;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.bio,
  });
}