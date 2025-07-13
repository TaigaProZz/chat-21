class User {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? bio;

  User({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.bio,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['uid'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
    );
  }
}
