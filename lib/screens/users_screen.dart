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
                Text(
                  'Discussions',
                  style: Theme.of(context).textTheme.titleLarge,
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
