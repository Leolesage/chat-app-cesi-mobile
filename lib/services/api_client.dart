import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/message.dart';
import '../models/user.dart';

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$normalized').replace(queryParameters: query);
  }

  Future<UserSession> authenticate({
    required String username,
    required String password,
  }) async {
    final response = await _client
        .post(
          _uri('/auth'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'password': password,
          }),
        )
        .timeout(AppConfig.requestTimeout);

    final payload = _decodePayload(response);
    final user = payload['user'];
    if (user is! Map<String, dynamic>) {
      throw ApiException('Utilisateur invalide');
    }

    final idValue = user['id'];
    final usernameValue = user['username'];
    if (idValue is! num || usernameValue is! String) {
      throw ApiException('Utilisateur invalide');
    }

    return UserSession(
      id: idValue.toInt(),
      username: usernameValue,
      created: payload['created'] == true,
    );
  }

  Future<List<UserSummary>> fetchUsers({required int excludeUserId}) async {
    final response = await _client
        .get(_uri('/users'))
        .timeout(AppConfig.requestTimeout);

    final payload = _decodePayload(response);
    final usersRaw = payload['users'];
    if (usersRaw is! List) {
      throw ApiException('Liste invalide');
    }

    final users = <UserSummary>[];
    for (final item in usersRaw) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final user = UserSummary.fromJson(item);
      if (user.id == excludeUserId) {
        continue;
      }
      users.add(user);
    }

    return users;
  }

  Future<List<ChatMessage>> fetchMessages({
    required int userId,
    required int peerId,
    int sinceId = 0,
  }) async {
    final response = await _client
        .get(
          _uri('/messages', {
            'user_id': userId.toString(),
            'with_id': peerId.toString(),
            'since_id': sinceId.toString(),
          }),
        )
        .timeout(AppConfig.requestTimeout);

    final payload = _decodePayload(response);
    final messagesRaw = payload['messages'];
    if (messagesRaw is! List) {
      throw ApiException('Messages invalides');
    }

    final messages = <ChatMessage>[];
    for (final item in messagesRaw) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      messages.add(ChatMessage.fromJson(item));
    }

    return messages;
  }

  Future<ChatMessage> sendMessage({
    required int senderId,
    required int receiverId,
    required String body,
  }) async {
    final response = await _client
        .post(
          _uri('/messages'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'sender_id': senderId,
            'receiver_id': receiverId,
            'body': body,
          }),
        )
        .timeout(AppConfig.requestTimeout);

    final payload = _decodePayload(response);
    final messageRaw = payload['message'];
    if (messageRaw is! Map<String, dynamic>) {
      throw ApiException('Message invalide');
    }

    return ChatMessage.fromJson(messageRaw);
  }

  Map<String, dynamic> _decodePayload(http.Response response) {
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw ApiException('Reponse invalide du serveur');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(payload['message']?.toString() ?? 'Erreur serveur');
    }

    if (payload['status'] != 'ok') {
      throw ApiException(payload['message']?.toString() ?? 'Erreur serveur');
    }

    return payload;
  }
}
