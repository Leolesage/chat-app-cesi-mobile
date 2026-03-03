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

    final lastSeenAt = _parseApiDateTime(json['last_seen_at']);

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

    final createdAt = _parseApiDateTime(json['created_at']);
    final lastSeenAt = _parseApiDateTime(json['last_seen_at']);

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

DateTime? _parseApiDateTime(dynamic rawValue) {
  if (rawValue is! String || rawValue.isEmpty) {
    return null;
  }

  final value = rawValue.trim();
  if (value.isEmpty) {
    return null;
  }

  final hasTimezone =
      value.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(value);
  final normalized = hasTimezone
      ? value
      : value.contains(' ')
      ? '${value.replaceFirst(' ', 'T')}Z'
      : value;

  final parsed = DateTime.tryParse(normalized) ?? DateTime.tryParse(value);
  if (parsed == null) {
    return null;
  }

  return parsed.isUtc ? parsed.toLocal() : parsed;
}
