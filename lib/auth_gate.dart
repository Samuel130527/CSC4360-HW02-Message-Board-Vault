
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_screen.dart';
import 'auth_service.dart';
import 'user_service.dart';
import 'board_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = AuthService();
  late final Stream<User?> _authStream = _auth.authState;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Authentication unavailable.'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const AuthScreen();
        }

        return ProfileGate(
          key: ValueKey(user.uid),
          user: user,
        );
      },
    );
  }
}

class ProfileGate extends StatefulWidget {
  final User user;

  const ProfileGate({
    super.key,
    required this.user,
  });

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  final _users = UserService();
  final _auth = AuthService();

  late final _profileStream =
      _users.watchProfile(widget.user.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _profileStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Profile Error'),
              actions: [
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: () => _auth.signOut(),
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
            body: const Center(
              child: Text(
                'Could not load profile. Check Firestore rules.',
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final data = snapshot.data!.data();

        final valid = data != null &&
            data['uid'] == widget.user.uid &&
            data['firstName'] is String &&
            (data['firstName'] as String).trim().isNotEmpty &&
            data['lastName'] is String &&
            (data['lastName'] as String).trim().isNotEmpty &&
            data['role'] == 'member' &&
            data['registrationDateTime'] != null;

        if (!valid) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Profile Incomplete'),
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Your account exists, but your profile '
                    'needs to be completed.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _auth.signOut(),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          );
        }

        // Valid profile: open the live message board.
        return const BoardScreen();
      },
    );
  }
}
