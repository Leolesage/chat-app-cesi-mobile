import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String apiBaseUrl = 'http://10.0.2.2:8080';

void main() {
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CESI Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showMessage('Username et mot de passe obligatoires');
      return;
    }

    if (_isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/auth'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 8));

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        _showMessage('Reponse invalide du serveur');
        return;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _showMessage(payload['message']?.toString() ?? 'Erreur serveur');
        return;
      }

      if (payload['status'] != 'ok') {
        _showMessage(payload['message']?.toString() ?? 'Connexion refusee');
        return;
      }

      final user = payload['user'];
      if (user is! Map<String, dynamic>) {
        _showMessage('Utilisateur invalide');
        return;
      }

      final idValue = user['id'];
      final usernameValue = user['username'];
      if (idValue is! num || usernameValue is! String) {
        _showMessage('Utilisateur invalide');
        return;
      }

      final session = UserSession(
        id: idValue.toInt(),
        username: usernameValue,
        created: payload['created'] == true,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => UsersScreen(session: session),
        ),
      );
    } catch (error) {
      _showMessage('Impossible de contacter l\'API');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'CESI Chat',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Connecte-toi pour commencer',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Se connecter'),
              ),
              const SizedBox(height: 12),
              Text(
                'Le compte est cree automatiquement si l\'utilisateur n\'existe pas.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserSession {
  const UserSession({
    required this.id,
    required this.username,
    required this.created,
  });

  final int id;
  final String username;
  final bool created;
}

class UserSummary {
  const UserSummary({
    required this.id,
    required this.username,
  });

  final int id;
  final String username;

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    final usernameValue = json['username'];
    if (idValue is! num || usernameValue is! String) {
      throw const FormatException('Utilisateur invalide');
    }

    return UserSummary(
      id: idValue.toInt(),
      username: usernameValue,
    );
  }
}

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.session});

  final UserSession session;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late Future<List<UserSummary>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _fetchUsers();
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
      final response = await http
          .get(Uri.parse('$apiBaseUrl/users'))
          .timeout(const Duration(seconds: 8));

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        throw const FormatException('Reponse invalide');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(payload['message']?.toString() ?? 'Erreur serveur');
      }

      if (payload['status'] != 'ok') {
        throw Exception(payload['message']?.toString() ?? 'Erreur serveur');
      }

      final usersRaw = payload['users'];
      if (usersRaw is! List) {
        throw const FormatException('Liste invalide');
      }

      final users = <UserSummary>[];
      for (final item in usersRaw) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final user = UserSummary.fromJson(item);
        if (user.id == widget.session.id) {
          continue;
        }
        users.add(user);
      }

      return users;
    } catch (error) {
      _showMessage('Impossible de charger les utilisateurs');
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusText = widget.session.created
        ? 'Compte cree avec succes.'
        : 'Connexion reussie.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Utilisateurs'),
        actions: [
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connecte en tant que ${widget.session.username}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('ID utilisateur: ${widget.session.id}'),
            const SizedBox(height: 8),
            Text(statusText),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<UserSummary>>(
                future: _usersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
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

                  final users = snapshot.data ?? <UserSummary>[];
                  if (users.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final label = user.username.trim();
                        final initial = label.isEmpty
                            ? '?'
                            : label.substring(0, 1).toUpperCase();

                        return ListTile(
                          leading: CircleAvatar(child: Text(initial)),
                          title: Text(user.username),
                          subtitle: Text('ID: ${user.id}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openChat(user),
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
    );
  }
}

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.session,
    required this.peer,
  });

  final UserSession session;
  final UserSummary peer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(peer.username),
      ),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Etape suivante: messages.'),
      ),
    );
  }
}
