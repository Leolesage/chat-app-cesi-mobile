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
  List<UserSummary> _users = [];
  String _query = '';
  String? _errorMessage;
  bool _isLoading = true;
  Timer? _presenceTimer;
  Timer? _refreshTimer;
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_handleSearchChange);
    _loadUsers(showLoading: true);
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
    setState(() {
      _query = _searchController.text.trim().toLowerCase();
    });
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
      (_) => _loadUsers(),
    );
  }

  Future<void> _sendPresence() async {
    try {
      await widget.apiClient.updatePresence(userId: widget.session.id);
    } catch (_) {
      // silent
    }
  }

  Future<void> _loadUsers({bool showLoading = false}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final users = await widget.apiClient.fetchUsers(
        excludeUserId: widget.session.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _users = users;
        _errorMessage = null;
        _isLoading = false;
      });
    } on ApiException catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Impossible de charger les utilisateurs';
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Impossible de contacter l\'API';
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadUsers();
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

  void _showAddUserSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AddUserSheet(
          sessionId: widget.session.id,
          sessionUsername: widget.session.username,
          apiClient: widget.apiClient,
          onOpenChat: (user) {
            Navigator.of(context).pop();
            _openChat(user);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusText = widget.session.created
        ? 'Compte cree avec succes.'
        : 'Connexion reussie.';
    final filteredUsers = _filterUsers(_users);
    final topFriends = _topFriends(filteredUsers);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            tooltip: 'Ajouter un contact',
            onPressed: _showAddUserSheet,
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
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
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
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
                    TextButton.icon(
                      onPressed: _showAddUserSheet,
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: const Text('Ajouter'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Chats'),
                      selected: _activeTabIndex == 0,
                      onSelected: (_) {
                        setState(() {
                          _activeTabIndex = 0;
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('Amis proches'),
                      selected: _activeTabIndex == 1,
                      onSelected: (_) {
                        setState(() {
                          _activeTabIndex = 1;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un utilisateur',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                if (_activeTabIndex == 1 && topFriends.isNotEmpty) ...[
                  Text(
                    'Amis de flamme',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: topFriends.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final friend = topFriends[index];
                        final streak = _streakForUser(friend);
                        return Container(
                          width: 120,
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
                              Text('Flamme $streak'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_errorMessage!),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: _refresh,
                                    child: const Text('Reessayer'),
                                  ),
                                ],
                              ),
                            )
                          : _buildUsersList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUsersList() {
    final users = _filterUsers(_users);

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 36),
            const SizedBox(height: 12),
            const Text('Aucun autre utilisateur pour l\'instant.'),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _refresh,
              child: const Text('Rafraichir'),
            ),
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
}

class _AddUserSheet extends StatefulWidget {
  const _AddUserSheet({
    required this.sessionId,
    required this.sessionUsername,
    required this.apiClient,
    required this.onOpenChat,
  });

  final int sessionId;
  final String sessionUsername;
  final ApiClient apiClient;
  final ValueChanged<UserSummary> onOpenChat;

  @override
  State<_AddUserSheet> createState() => _AddUserSheetState();
}

class _AddUserSheetState extends State<_AddUserSheet> {
  final TextEditingController _controller = TextEditingController();
  List<UserSummary> _allUsers = [];
  List<UserSummary> _filteredUsers = [];
  bool _isLoading = true;
  int _streakForUser(UserSummary user) {
    if (_isLeoAntoinePair(user)) {
      return 12;
    }
    final seed = user.username.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return 1 + (seed % 12);
  }

  bool _isLeoAntoinePair(UserSummary user) {
    final a = widget.sessionUsername.toLowerCase();
    final b = user.username.toLowerCase();
    return (a == 'leo' && b == 'antoine') || (a == 'antoine' && b == 'leo');
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _controller.addListener(_filter);
  }

  @override
  void dispose() {
    _controller.removeListener(_filter);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await widget.apiClient.fetchUsers(
        excludeUserId: widget.sessionId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _allUsers = [];
        _filteredUsers = [];
        _isLoading = false;
      });
    }
  }

  void _filter() {
    final query = _controller.text.trim().toLowerCase();
    setState(() {
      _filteredUsers = _allUsers
          .where((user) => user.username.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets +
        const EdgeInsets.symmetric(horizontal: 24, vertical: 20);

    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.person_add_alt_1_rounded),
                const SizedBox(width: 12),
                Text(
                  'Ajouter un contact',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Rechercher un utilisateur',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else if (_filteredUsers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucun utilisateur trouve.'),
              )
            else
              SizedBox(
                height: 300,
                child: ListView.separated(
                  itemCount: _filteredUsers.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    final streak = _streakForUser(user);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: UserAvatar(
                        label: user.username,
                        isOnline: user.isOnline,
                      ),
                      title: Text(user.username),
                      subtitle: Text(
                        user.isOnline
                            ? 'En ligne'
                            : 'Hors ligne',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Flamme $streak'),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline),
                            onPressed: () => widget.onOpenChat(user),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
