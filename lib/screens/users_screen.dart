import 'package:flutter/material.dart';

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

class _UsersScreenState extends State<UsersScreen> {
  final _searchController = TextEditingController();
  late Future<List<UserSummary>> _usersFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _usersFuture = _fetchUsers();
    _searchController.addListener(_handleSearchChange);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChange);
    _searchController.dispose();
    super.dispose();
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

  Future<List<UserSummary>> _fetchUsers() async {
    try {
      return await widget.apiClient.fetchUsers(
        excludeUserId: widget.session.id,
      );
    } on ApiException catch (_) {
      _showMessage('Impossible de charger les utilisateurs');
      rethrow;
    } catch (_) {
      _showMessage('Impossible de contacter l\'API');
      rethrow;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _usersFuture = _fetchUsers();
    });
    await _usersFuture;
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

  void _showAddUserSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AddUserSheet(
          sessionId: widget.session.id,
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
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un utilisateur',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: FutureBuilder<List<UserSummary>>(
                    future: _usersFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Erreur de chargement.'),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _refresh,
                                child: const Text('Reessayer'),
                              ),
                            ],
                          ),
                        );
                      }

                      final users = _filterUsers(
                        snapshot.data ?? <UserSummary>[],
                      );

                      if (users.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_outline, size: 36),
                              const SizedBox(height: 12),
                              const Text(
                                'Aucun autre utilisateur pour l\'instant.',
                              ),
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
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final user = users[index];

                            return Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                leading: UserAvatar(
                                  label: user.username,
                                  isOnline: true,
                                ),
                                title: Text(user.username),
                                subtitle: const Text('Disponible'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _openChat(user),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddUserSheet extends StatefulWidget {
  const _AddUserSheet({
    required this.sessionId,
    required this.apiClient,
    required this.onOpenChat,
  });

  final int sessionId;
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
                child: Text('Aucun utilisateur trouv�.'),
              )
            else
              SizedBox(
                height: 300,
                child: ListView.separated(
                  itemCount: _filteredUsers.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: UserAvatar(label: user.username),
                      title: Text(user.username),
                      trailing: IconButton(
                        icon: const Icon(Icons.chat_bubble_outline),
                        onPressed: () => widget.onOpenChat(user),
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
