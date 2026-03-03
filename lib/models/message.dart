class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.body,
    this.createdAt,
    this.readAt,
  });

  final int id;
  final int senderId;
  final int receiverId;
  final String body;
  final DateTime? createdAt;
  DateTime? readAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    final senderValue = json['sender_id'];
    final receiverValue = json['receiver_id'];
    final bodyValue = json['body'];

    if (idValue is! num || senderValue is! num || receiverValue is! num) {
      throw const FormatException('Message invalide');
    }

    if (bodyValue is! String) {
      throw const FormatException('Message invalide');
    }

    final createdAt = _parseApiDateTime(json['created_at']);
    final readAt = _parseApiDateTime(json['read_at']);

    return ChatMessage(
      id: idValue.toInt(),
      senderId: senderValue.toInt(),
      receiverId: receiverValue.toInt(),
      body: bodyValue,
      createdAt: createdAt,
      readAt: readAt,
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
