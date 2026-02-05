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

    final createdRaw = json['created_at'];
    DateTime? createdAt;
    if (createdRaw is String && createdRaw.isNotEmpty) {
      createdAt = DateTime.tryParse(createdRaw);
    }

    final readRaw = json['read_at'];
    DateTime? readAt;
    if (readRaw is String && readRaw.isNotEmpty) {
      readAt = DateTime.tryParse(readRaw);
    }

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
