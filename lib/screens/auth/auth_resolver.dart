import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_services.dart';
import '../home/main_screen.dart';
import 'login_screen.dart';

class AuthResolver extends StatelessWidget {
  const AuthResolver({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Colors.orange),
            ),
          );
        }

        // If user is logged in
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          final AuthService authService = AuthService();

          // Fetch the user's role before navigating to HomeScreen
          return FutureBuilder<String>(
            future: authService.getUserRole(user.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  ),
                );
              }

              // After fetching role, return HomeScreen
              final role = roleSnapshot.data ?? 'student'; // Fallback
              return HomeScreen(role: role);
            },
          );
        }

        // Default to login if no user is found
        return const LoginScreen();
      },
    );
  }
}
