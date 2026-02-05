import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/user.dart';
import '../services/api_client.dart';
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

class _UsersScreenState extends State<UsersScreen>
    with WidgetsBindingObserver {
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
  Timer? _presenceTimer;
  Timer? _refreshTimer;
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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

  void _openChat(UserSummary user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          session: widget.session,
          peer: user,
          apiClient: widget.apiClient,
        ),
      ),
    );
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
        .where((request) =>
            request.fromUser.username.toLowerCase().contains(_query))
        .toList();
  }

  int _streakForUser(UserSummary user) {
    if (_isLeoAntoinePair(user)) {
      return 12;
    }
    final seed = user.username.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return 1 + (seed % 12);
  }

  bool _isBestFriend(UserSummary user) {
    if (_isLeoAntoinePair(user)) {
      return true;
    }
    final seed = user.username.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return seed % 5 == 0;
  }

  bool _isLeoAntoinePair(UserSummary user) {
    final a = widget.session.username.toLowerCase();
    final b = user.username.toLowerCase();
    final isLeoAntoine =
        (a == 'leo' && b == 'antoine') || (a == 'antoine' && b == 'leo');
    return isLeoAntoine;
  }

  List<UserSummary> _topFriends(List<UserSummary> users) {
    final sorted = [...users];
    sorted.sort((a, b) => _streakForUser(b).compareTo(_streakForUser(a)));
    return sorted.take(5).toList();
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
    final topFriends = _topFriends(filteredFriends);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            tooltip: 'Rafraichir',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Deconnexion'),
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
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              Text('ID utilisateur: ${widget.session.id}'),
                              const SizedBox(height: 6),
                              Text(
                                statusText,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.7),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const Chip(label: Text('Flamme 12')),
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
                    ChoiceChip(
                      label: const Text('Chats'),
                      selected: _activeTabIndex == 0,
                      onSelected: (_) => _setActiveTab(0),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('Invitations'),
                      selected: _activeTabIndex == 1,
                      onSelected: (_) => _setActiveTab(1),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('Trouver'),
                      selected: _activeTabIndex == 2,
                      onSelected: (_) => _setActiveTab(2),
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
                if (_activeTabIndex == 0 && topFriends.isNotEmpty) ...[
                  Text(
                    'Amis de flamme',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 126,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: topFriends.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final friend = topFriends[index];
                        final streak = _streakForUser(friend);
                        return Container(
                          width: 124,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.96),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              UserAvatar(
                                label: friend.username,
                                isOnline: friend.isOnline,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                friend.username,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Flamme $streak',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
            ElevatedButton(
              onPressed: _refresh,
              child: const Text('Reessayer'),
            ),
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

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: friends.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final user = friends[index];
          final statusText = user.isOnline
              ? 'En ligne'
              : _formatLastSeen(user.lastSeenAt);
          final streak = _streakForUser(user);
          final isBestFriend = _isBestFriend(user);

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
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Meilleur ami',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              subtitle: Text(statusText),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Flamme $streak'),
                  const SizedBox(width: 8),
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
            ElevatedButton(
              onPressed: _refresh,
              child: const Text('Reessayer'),
            ),
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
        separatorBuilder: (_, __) => const SizedBox(height: 12),
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
            ElevatedButton(
              onPressed: _refresh,
              child: const Text('Reessayer'),
            ),
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
        separatorBuilder: (_, __) => const SizedBox(height: 12),
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
