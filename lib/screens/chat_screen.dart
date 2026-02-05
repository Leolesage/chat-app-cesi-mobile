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
  bool _peerOnline = false;
  DateTime? _peerLastSeen;
  DateTime? _lastPeerRefresh;
  String? _errorMessage;
  int _lastReadId = 0;

  @override
  void initState() {
    super.initState();
    _peerOnline = widget.peer.isOnline;
    _peerLastSeen = widget.peer.lastSeenAt;
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
      _errorMessage = null;
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

      await _markReadIfNeeded();
      await _refreshReadStatus();

      if (mounted) {
        setState(() {});
      }

      if (nextMessages.isNotEmpty) {
        _scrollToBottom();
      }

      await _refreshPeerStatusIfNeeded();
    } on ApiException catch (_) {
      if (replace) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Impossible de charger les messages';
          });
        }
      }
    } catch (_) {
      if (replace) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Impossible de contacter l\'API';
          });
        }
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _markReadIfNeeded() async {
    final unreadFromPeer = _messages
        .where((message) =>
            message.senderId == widget.peer.id && message.readAt == null)
        .toList();

    if (unreadFromPeer.isEmpty) {
      return;
    }

    final upToId = unreadFromPeer
        .map((message) => message.id)
        .fold<int>(0, (maxId, id) => id > maxId ? id : maxId);

    try {
      await widget.apiClient.markMessagesRead(
        userId: widget.session.id,
        withId: widget.peer.id,
        upToId: upToId,
      );

      final now = DateTime.now();
      for (final message in _messages) {
        if (message.senderId == widget.peer.id &&
            message.readAt == null &&
            message.id <= upToId) {
          message.readAt = now;
        }
      }
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _refreshReadStatus() async {
    try {
      final lastReadId = await widget.apiClient.fetchLastReadId(
        userId: widget.session.id,
        withId: widget.peer.id,
      );

      if (lastReadId <= _lastReadId) {
        return;
      }
      _lastReadId = lastReadId;

      final now = DateTime.now();
      for (final message in _messages) {
        if (message.senderId == widget.session.id &&
            message.readAt == null &&
            message.id <= lastReadId) {
          message.readAt = now;
        }
      }
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _refreshPeerStatusIfNeeded() async {
    final now = DateTime.now();
    if (_lastPeerRefresh != null &&
        now.difference(_lastPeerRefresh!) < AppConfig.usersRefreshInterval) {
      return;
    }
    _lastPeerRefresh = now;

    try {
      final users = await widget.apiClient.fetchFriends(
        userId: widget.session.id,
      );
      final peer = users.firstWhere(
        (user) => user.id == widget.peer.id,
        orElse: () => widget.peer,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _peerOnline = peer.isOnline;
        _peerLastSeen = peer.lastSeenAt;
      });
    } catch (_) {
      // ignore
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
        setState(() {
          _errorMessage = null;
        });
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

  Widget _buildErrorBanner(ColorScheme colorScheme) {
    if (_errorMessage == null) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _isFetching ? null : _loadInitial,
            child: const Text('Reessayer'),
          ),
        ],
      ),
    );
  }

  String _formatLastSeen(DateTime? lastSeenAt) {
    if (lastSeenAt == null) {
      return 'Hors ligne';
    }

    final diff = DateTime.now().difference(lastSeenAt);
    if (diff.inSeconds < 60) {
      return 'Vu a l\'instant';
    }
    if (diff.inMinutes < 60) {
      return 'Vu il y a ${diff.inMinutes} min';
    }
    if (diff.inHours < 24) {
      return 'Vu il y a ${diff.inHours} h';
    }
    return 'Vu il y a ${diff.inDays} j';
  }

  int _streakForPeer() {
    if (_isLeoAntoinePair()) {
      return 12;
    }
    final seed =
        widget.peer.username.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return 1 + (seed % 12);
  }

  bool _isLeoAntoinePair() {
    final a = widget.session.username.toLowerCase();
    final b = widget.peer.username.toLowerCase();
    return (a == 'leo' && b == 'antoine') || (a == 'antoine' && b == 'leo');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusText = _peerOnline ? 'En ligne' : _formatLastSeen(_peerLastSeen);
    final streak = _streakForPeer();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(
              label: widget.peer.username,
              size: 40,
              isOnline: _peerOnline,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.peer.username),
                Text(
                  statusText,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text('Flamme $streak'),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
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
            _buildErrorBanner(colorScheme),
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
