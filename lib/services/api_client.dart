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

  Future<List<UserSummary>> fetchFriends({required int userId}) async {
    final response = await _client
        .get(_uri('/friends', {'user_id': userId.toString()}))
        .timeout(AppConfig.requestTimeout);

    final payload = _decodePayload(response);
    final usersRaw = payload['friends'];
    if (usersRaw is! List) {
      throw ApiException('Liste invalide');
    }

    final users = <UserSummary>[];
    for (final item in usersRaw) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      users.add(UserSummary.fromJson(item));
    }

    return users;
  }

  Future<List<FriendRequest>> fetchFriendRequests({required int userId}) async {
    final response = await _client
        .get(_uri('/friends/requests', {'user_id': userId.toString()}))
        .timeout(AppConfig.requestTimeout);

    final payload = _decodePayload(response);
    final requestsRaw = payload['requests'];
    if (requestsRaw is! List) {
      throw ApiException('Liste invalide');
    }

    final requests = <FriendRequest>[];
    for (final item in requestsRaw) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      requests.add(FriendRequest.fromJson(item));
    }

    return requests;
  }

  Future<List<UserSummary>> discoverUsers({
    required int userId,
    String query = '',
  }) async {
    final response = await _client
        .get(_uri('/users/discover', {
          'user_id': userId.toString(),
          'query': query,
        }))
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
      users.add(UserSummary.fromJson(item));
    }

    return users;
  }

  Future<void> sendFriendRequest({
    required int fromUserId,
    required int toUserId,
  }) async {
    final response = await _client
        .post(
          _uri('/friends/request'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'from_user_id': fromUserId,
            'to_user_id': toUserId,
          }),
        )
        .timeout(AppConfig.requestTimeout);

    _decodePayload(response);
  }

  Future<void> acceptFriendRequest({
    required int fromUserId,
    required int toUserId,
  }) async {
    final response = await _client
        .post(
          _uri('/friends/accept'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'from_user_id': fromUserId,
            'to_user_id': toUserId,
          }),
        )
        .timeout(AppConfig.requestTimeout);

    _decodePayload(response);
  }

  Future<void> declineFriendRequest({
    required int fromUserId,
    required int toUserId,
  }) async {
    final response = await _client
        .post(
          _uri('/friends/decline'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'from_user_id': fromUserId,
            'to_user_id': toUserId,
          }),
        )
        .timeout(AppConfig.requestTimeout);

    _decodePayload(response);
  }

  Future<void> updatePresence({required int userId}) async {
    final response = await _client
        .post(
          _uri('/presence'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': userId}),
        )
        .timeout(AppConfig.requestTimeout);

    _decodePayload(response);
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

  Future<void> markMessagesRead({
    required int userId,
    required int withId,
    int upToId = 0,
  }) async {
    final response = await _client
        .post(
          _uri('/messages/read'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'with_id': withId,
            'up_to_id': upToId,
          }),
        )
        .timeout(AppConfig.requestTimeout);

    _decodePayload(response);
  }

  Future<int> fetchLastReadId({
    required int userId,
    required int withId,
  }) async {
    final response = await _client
        .get(_uri('/messages/read', {
          'user_id': userId.toString(),
          'with_id': withId.toString(),
        }))
        .timeout(AppConfig.requestTimeout);

    final payload = _decodePayload(response);
    final value = payload['last_read_id'];
    if (value is! num) {
      return 0;
    }
    return value.toInt();
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
