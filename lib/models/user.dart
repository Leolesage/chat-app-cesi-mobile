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

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.fromUser,
    required this.createdAt,
  });

  final int id;
  final UserSummary fromUser;
  final DateTime? createdAt;

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    if (idValue is! num) {
      throw const FormatException('Invitation invalide');
    }

    final fromUserId = json['from_user_id'];
    final usernameValue = json['username'];
    final isOnlineValue = json['is_online'];
    if (fromUserId is! num || usernameValue is! String) {
      throw const FormatException('Invitation invalide');
    }

    final createdRaw = json['created_at'];
    DateTime? createdAt;
    if (createdRaw is String && createdRaw.isNotEmpty) {
      createdAt = DateTime.tryParse(createdRaw);
    }

    final lastSeenRaw = json['last_seen_at'];
    DateTime? lastSeenAt;
    if (lastSeenRaw is String && lastSeenRaw.isNotEmpty) {
      lastSeenAt = DateTime.tryParse(lastSeenRaw);
    }

    final isOnline = isOnlineValue == true || isOnlineValue == 1;

    return FriendRequest(
      id: idValue.toInt(),
      fromUser: UserSummary(
        id: fromUserId.toInt(),
        username: usernameValue,
        isOnline: isOnline,
        lastSeenAt: lastSeenAt,
      ),
      createdAt: createdAt,
    );
  }
}
