class UserSession {
  const UserSession({
    required this.id,
    required this.username,
    required this.created,
  });

  final int id;
  final String username;
  final bool created;
}

class UserSummary {
  const UserSummary({
    required this.id,
    required this.username,
    required this.isOnline,
    required this.lastSeenAt,
  });

  final int id;
  final String username;
  final bool isOnline;
  final DateTime? lastSeenAt;

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    final usernameValue = json['username'];
    final isOnlineValue = json['is_online'];
    if (idValue is! num || usernameValue is! String) {
      throw const FormatException('Utilisateur invalide');
    }

    final lastSeenRaw = json['last_seen_at'];
    DateTime? lastSeenAt;
    if (lastSeenRaw is String && lastSeenRaw.isNotEmpty) {
      lastSeenAt = DateTime.tryParse(lastSeenRaw);
    }

    final isOnline = isOnlineValue == true || isOnlineValue == 1;

    return UserSummary(
      id: idValue.toInt(),
      username: usernameValue,
      isOnline: isOnline,
      lastSeenAt: lastSeenAt,
    );
  }
}
