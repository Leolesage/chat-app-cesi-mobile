import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/notification_sound_service.dart';
import '../widgets/app_background.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({
    super.key,
    required this.session,
    required this.apiClient,
  });

  final UserSession session;
  final ApiClient apiClient;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  List<UserSummary> _friends = [];
  List<UserSummary> _discoverUsers = [];
  List<FriendRequest> _requests = [];
  String _query = '';
  String? _friendsError;
  String? _requestsError;
  String? _discoverError;
  bool _isLoadingFriends = true;
  bool _isLoadingRequests = false;
  bool _isLoadingDiscover = false;
  bool _isRefreshingPending = false;
  bool _pendingInitialized = false;
  Timer? _presenceTimer;
  Timer? _refreshTimer;
  Map<int, int> _pendingByUser = {};
  int _pendingTotal = 0;
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_handleSearchChange);
    _loadFriends(showLoading: true);
    _loadRequests(showLoading: true);
    _loadDiscover(showLoading: true);
    _startPresence();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.removeListener(_handleSearchChange);
    _searchController.dispose();
    _presenceTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPresence();
      _startAutoRefresh();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _presenceTimer?.cancel();
      _refreshTimer?.cancel();
    }
  }

  void _handleSearchChange() {
    final value = _searchController.text.trim().toLowerCase();
    setState(() {
      _query = value;
    });

    if (_activeTabIndex == 2) {
      _loadDiscover(showLoading: false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _startPresence() {
    _presenceTimer?.cancel();
    _sendPresence();
    _presenceTimer = Timer.periodic(
      AppConfig.presenceInterval,
      (_) => _sendPresence(),
    );
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      AppConfig.usersRefreshInterval,
      (_) => _loadFriends(),
    );
  }

  Future<void> _sendPresence() async {
    try {
      await widget.apiClient.updatePresence(userId: widget.session.id);
    } catch (_) {
      // silent
    }
  }

  Future<void> _loadFriends({bool showLoading = false}) async {
    if (showLoading) {
      setState(() {
        _isLoadingFriends = true;
        _friendsError = null;
      });
    }

    try {
      final users = await widget.apiClient.fetchFriends(
        userId: widget.session.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _friends = users;
        _friendsError = null;
        _isLoadingFriends = false;
      });

      unawaited(_refreshPendingMessages(users));
    } on ApiException catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _friendsError = 'Impossible de charger les amis';
        _isLoadingFriends = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _friendsError = 'Impossible de contacter l\'API';
        _isLoadingFriends = false;
      });
    }
  }

  Future<void> _loadRequests({bool showLoading = false}) async {
    if (showLoading) {
      setState(() {
        _isLoadingRequests = true;
        _requestsError = null;
      });
    }

    try {
      final requests = await widget.apiClient.fetchFriendRequests(
        userId: widget.session.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _requests = requests;
        _requestsError = null;
        _isLoadingRequests = false;
      });
    } on ApiException catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _requestsError = 'Impossible de charger les invitations';
        _isLoadingRequests = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _requestsError = 'Impossible de contacter l\'API';
        _isLoadingRequests = false;
      });
    }
  }

  Future<void> _loadDiscover({bool showLoading = false}) async {
    if (showLoading) {
      setState(() {
        _isLoadingDiscover = true;
        _discoverError = null;
      });
    }

    try {
      final users = await widget.apiClient.discoverUsers(
        userId: widget.session.id,
        query: _query,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _discoverUsers = users;
        _discoverError = null;
        _isLoadingDiscover = false;
      });
    } on ApiException catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _discoverError = 'Impossible de charger les suggestions';
        _isLoadingDiscover = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _discoverError = 'Impossible de contacter l\'API';
        _isLoadingDiscover = false;
      });
    }
  }

  Future<void> _refreshPendingMessages(List<UserSummary> friends) async {
    if (_isRefreshingPending) {
      return;
    }

    _isRefreshingPending = true;
    final nextPendingByUser = <int, int>{};

    try {
      for (final user in friends) {
        final lastReadId = await widget.apiClient.fetchLastReadId(
          userId: widget.session.id,
          withId: user.id,
        );

        final deltaMessages = await widget.apiClient.fetchMessages(
          userId: widget.session.id,
          peerId: user.id,
          sinceId: lastReadId,
        );

        final pendingCount = deltaMessages
            .where(
              (message) =>
                  message.senderId == user.id && message.readAt == null,
            )
            .length;

        if (pendingCount > 0) {
          nextPendingByUser[user.id] = pendingCount;
        }
      }
    } catch (_) {
      // silent
    } finally {
      _isRefreshingPending = false;
    }

    if (!mounted) {
      return;
    }

    final nextTotal = nextPendingByUser.values.fold<int>(
      0,
      (total, value) => total + value,
    );
    final shouldPlaySound = _pendingInitialized && nextTotal > _pendingTotal;

    setState(() {
      _pendingByUser = nextPendingByUser;
      _pendingTotal = nextTotal;
      _pendingInitialized = true;
    });

    if (shouldPlaySound) {
      unawaited(NotificationSoundService.playIncomingMessage());
    }
  }

  Future<void> _refresh() async {
    if (_activeTabIndex == 0) {
      await _loadFriends(showLoading: true);
      return;
    }
    if (_activeTabIndex == 1) {
      await _loadRequests(showLoading: true);
      return;
    }
    await _loadDiscover(showLoading: true);
  }

  Future<void> _openChat(UserSummary user) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          session: widget.session,
          peer: user,
          apiClient: widget.apiClient,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadFriends();
  }

  List<UserSummary> _filterUsers(List<UserSummary> users) {
    if (_query.isEmpty) {
      return users;
    }

    return users
        .where((user) => user.username.toLowerCase().contains(_query))
        .toList();
  }

  List<FriendRequest> _filterRequests(List<FriendRequest> requests) {
    if (_query.isEmpty) {
      return requests;
    }

    return requests
        .where(
          (request) => request.fromUser.username.toLowerCase().contains(_query),
        )
        .toList();
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

  String _tabLabel(int index) {
    if (index == 1) {
      return 'Invitations';
    }
    if (index == 2) {
      return 'Trouver';
    }
    return 'Chats';
  }

  int? _bestFriendId(List<UserSummary> users) {
    if (users.isEmpty) {
      return null;
    }

    final sorted = [...users]
      ..sort((a, b) {
        final byName = a.username.toLowerCase().compareTo(
          b.username.toLowerCase(),
        );
        if (byName != 0) {
          return byName;
        }
        return a.id.compareTo(b.id);
      });

    return sorted.first.id;
  }

  Widget _buildTabMenuButton({
    required int index,
    required String label,
    int badgeCount = 0,
  }) {
    final selected = _activeTabIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    return OutlinedButton(
      onPressed: () => _setActiveTab(index),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? colorScheme.primaryContainer
            : Colors.white.withOpacity(0.9),
        side: BorderSide(
          color: selected
              ? colorScheme.primary
              : colorScheme.outline.withOpacity(0.35),
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (badgeCount > 0) ...[
            const SizedBox(width: 8),
            _buildPendingBadge(badgeCount),
          ],
        ],
      ),
    );
  }

  void _setActiveTab(int index) {
    setState(() {
      _activeTabIndex = index;
    });
    if (index == 1 && _requests.isEmpty) {
      _loadRequests(showLoading: true);
    }
    if (index == 2 && _discoverUsers.isEmpty) {
      _loadDiscover(showLoading: true);
    }
  }

  Widget _buildPendingBadge(int count) {
    final colorScheme = Theme.of(context).colorScheme;
    final text = count > 99 ? '99+' : '$count';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.error,
        borderRadius: BorderRadius.circular(999),
      ),
      constraints: const BoxConstraints(minWidth: 20),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onError,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMenuIconWithBadge() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.more_vert_rounded),
        if (_pendingTotal > 0)
          Positioned(
            right: -4,
            top: -6,
            child: _buildPendingBadge(_pendingTotal),
          ),
      ],
    );
  }

  String _pendingStatusLabel(UserSummary user) {
    final pending = _pendingByUser[user.id] ?? 0;
    if (pending <= 0) {
      return user.isOnline ? 'En ligne' : _formatLastSeen(user.lastSeenAt);
    }

    final suffix = pending > 1 ? 's' : '';
    return 'En attente: $pending message$suffix';
  }

  Future<void> _sendRequest(UserSummary user) async {
    try {
      await widget.apiClient.sendFriendRequest(
        fromUserId: widget.session.id,
        toUserId: user.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _discoverUsers.removeWhere((item) => item.id == user.id);
      });
      _showMessage('Invitation envoyee');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Impossible d\'envoyer l\'invitation');
    }
  }

  Future<void> _acceptRequest(FriendRequest request) async {
    try {
      await widget.apiClient.acceptFriendRequest(
        fromUserId: request.fromUser.id,
        toUserId: widget.session.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _requests.removeWhere((item) => item.id == request.id);
      });
      await _loadFriends(showLoading: true);
      _showMessage('Ami ajoute');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Impossible d\'accepter l\'invitation');
    }
  }

  Future<void> _declineRequest(FriendRequest request) async {
    try {
      await widget.apiClient.declineFriendRequest(
        fromUserId: request.fromUser.id,
        toUserId: widget.session.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _requests.removeWhere((item) => item.id == request.id);
      });
      _showMessage('Invitation refusee');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Impossible de refuser l\'invitation');
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusText = widget.session.created
        ? 'Compte cree avec succes.'
        : 'Connexion reussie.';
    final filteredFriends = _filterUsers(_friends);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            tooltip: 'Rafraichir',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu',
            icon: _buildMenuIconWithBadge(),
            onSelected: (value) {
              if (value == 'logout') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                value: 'pending_info',
                child: Text(
                  _pendingTotal > 0
                      ? '$_pendingTotal message(s) en attente'
                      : 'Aucun message en attente',
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('Deconnexion'),
              ),
            ],
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        UserAvatar(label: widget.session.username),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.session.username,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              Text('ID utilisateur: ${widget.session.id}'),
                              const SizedBox(height: 6),
                              Text(
                                statusText,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Discussions',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (_pendingTotal > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$_pendingTotal en attente',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    if (_pendingTotal > 0) const SizedBox(width: 8),
                    if (_activeTabIndex == 2)
                      TextButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Rafraichir'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTabMenuButton(
                        index: 0,
                        label: _tabLabel(0),
                        badgeCount: _pendingTotal,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTabMenuButton(index: 1, label: _tabLabel(1)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTabMenuButton(index: 2, label: _tabLabel(2)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _activeTabIndex == 2
                        ? 'Rechercher un utilisateur'
                        : 'Rechercher dans les chats',
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _activeTabIndex == 0
                      ? _buildFriendsList(filteredFriends)
                      : _activeTabIndex == 1
                      ? _buildRequestsList(_filterRequests(_requests))
                      : _buildDiscoverList(_discoverUsers),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsList(List<UserSummary> friends) {
    if (_isLoadingFriends) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_friendsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_friendsError!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _refresh, child: const Text('Reessayer')),
          ],
        ),
      );
    }

    if (friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 36),
            const SizedBox(height: 12),
            const Text('Aucun ami pour l\'instant.'),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _setActiveTab(2),
              child: const Text('Trouver des amis'),
            ),
          ],
        ),
      );
    }

    final bestFriendId = _bestFriendId(friends);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: friends.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final user = friends[index];
          final isBestFriend = user.id == bestFriendId;
          final pendingCount = _pendingByUser[user.id] ?? 0;
          final statusText = _pendingStatusLabel(user);

          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: UserAvatar(
                label: user.username,
                isOnline: user.isOnline,
              ),
              title: Row(
                children: [
                  Expanded(child: Text(user.username)),
                  if (isBestFriend)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Meilleur ami',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Text(statusText),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pendingCount > 0) ...[
                    _buildPendingBadge(pendingCount),
                    const SizedBox(width: 8),
                  ],
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => _openChat(user),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestsList(List<FriendRequest> requests) {
    if (_isLoadingRequests) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_requestsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_requestsError!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _refresh, child: const Text('Reessayer')),
          ],
        ),
      );
    }

    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mail_outline, size: 36),
            const SizedBox(height: 12),
            const Text('Aucune invitation pour l\'instant.'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: requests.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final request = requests[index];
          final user = request.fromUser;
          final statusText = user.isOnline
              ? 'En ligne'
              : _formatLastSeen(user.lastSeenAt);

          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: UserAvatar(
                label: user.username,
                isOnline: user.isOnline,
              ),
              title: Text(user.username),
              subtitle: Text(statusText),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => _declineRequest(request),
                    child: const Text('Refuser'),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    onPressed: () => _acceptRequest(request),
                    child: const Text('Accepter'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiscoverList(List<UserSummary> users) {
    if (_isLoadingDiscover) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_discoverError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_discoverError!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _refresh, child: const Text('Reessayer')),
          ],
        ),
      );
    }

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 36),
            const SizedBox(height: 12),
            const Text('Aucun utilisateur a ajouter.'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: users.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final user = users[index];
          final statusText = user.isOnline
              ? 'En ligne'
              : _formatLastSeen(user.lastSeenAt);

          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: UserAvatar(
                label: user.username,
                isOnline: user.isOnline,
              ),
              title: Text(user.username),
              subtitle: Text(statusText),
              trailing: TextButton.icon(
                onPressed: () => _sendRequest(user),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Ajouter'),
              ),
            ),
          );
        },
      ),
    );
  }
}
