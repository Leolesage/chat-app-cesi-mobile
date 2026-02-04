import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../widgets/app_background.dart';
import '../widgets/message_bubble.dart';
import '../widgets/user_avatar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.session,
    required this.peer,
    required this.apiClient,
  });

  final UserSession session;
  final UserSummary peer;
  final ApiClient apiClient;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  Timer? _pollTimer;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isFetching = false;
  int _lastMessageId = 0;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _pollTimer = Timer.periodic(
      AppConfig.pollInterval,
      (_) => _fetchMessages(sinceId: _lastMessageId),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
    });

    await _fetchMessages(sinceId: 0, replace: true);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _fetchMessages({required int sinceId, bool replace = false}) async {
    if (_isFetching) {
      return;
    }

    _isFetching = true;
    try {
      final nextMessages = await widget.apiClient.fetchMessages(
        userId: widget.session.id,
        peerId: widget.peer.id,
        sinceId: sinceId,
      );

      if (replace) {
        _messages
          ..clear()
          ..addAll(nextMessages);
      } else {
        _messages.addAll(nextMessages);
      }

      for (final message in nextMessages) {
        if (message.id > _lastMessageId) {
          _lastMessageId = message.id;
        }
      }

      if (mounted) {
        setState(() {});
      }

      if (nextMessages.isNotEmpty) {
        _scrollToBottom();
      }
    } on ApiException catch (_) {
      if (replace) {
        _showMessage('Impossible de charger les messages');
      }
    } catch (_) {
      if (replace) {
        _showMessage('Impossible de contacter l\'API');
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _isSending) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSending = true;
    });

    try {
      final message = await widget.apiClient.sendMessage(
        senderId: widget.session.id,
        receiverId: widget.peer.id,
        body: body,
      );

      _messages.add(message);
      if (message.id > _lastMessageId) {
        _lastMessageId = message.id;
      }

      _messageController.clear();
      if (mounted) {
        setState(() {});
      }
      _scrollToBottom();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Impossible d\'envoyer le message');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 40,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
          ),
          const SizedBox(height: 12),
          const Text('Aucun message pour l\'instant.'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(
              label: widget.peer.username,
              size: 40,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.peer.username),
                Text(
                  'En ligne',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Plus',
            onPressed: () {},
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: AppBackground(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return MessageBubble(
                              message: message,
                              isMe: message.senderId == widget.session.id,
                            );
                          },
                        ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.96),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: colorScheme.primary,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Ecrire un message...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isSending ? null : _sendMessage,
                        icon: _isSending
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.send_rounded,
                                color: colorScheme.primary,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
