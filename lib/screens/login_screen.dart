import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import '../services/auth_services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                /// BACK BUTTON
                const Icon(Icons.arrow_back, color: Colors.white),

                const SizedBox(height: 20),

                /// IMAGE
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    "https://images.unsplash.com/photo-1562774053-701939374585",
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(height: 30),

                /// TITLE
                const Center(
                  child: Text(
                    "Welcome Back",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                const Center(
                  child: Text(
                    "Login to manage and join campus events",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),

                const SizedBox(height: 30),

                /// EMAIL LABEL
                const Text(
                  "Student Email",
                  style: TextStyle(color: Colors.white),
                ),

                const SizedBox(height: 8),

                /// EMAIL FIELD
                TextField(
                  controller: emailController,

                  style: const TextStyle(color: Colors.white),

                  decoration: InputDecoration(
                    hintText: "name@university.edu",

                    hintStyle: const TextStyle(color: Colors.white54),

                    prefixIcon: const Icon(Icons.email, color: Colors.white54),

                    filled: true,
                    fillColor: const Color(0xFF1B263B),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// PASSWORD LABEL
                const Text("Password", style: TextStyle(color: Colors.white)),

                const SizedBox(height: 8),

                /// PASSWORD FIELD
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,

                  style: const TextStyle(color: Colors.white),

                  decoration: InputDecoration(
                    hintText: "Enter your password",

                    hintStyle: const TextStyle(color: Colors.white54),

                    prefixIcon: const Icon(Icons.lock, color: Colors.white54),

                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),

                    filled: true,
                    fillColor: const Color(0xFF1B263B),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                /// FORGOT PASSWORD
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text(
                      "Forgot password?",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// LOGIN BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2979FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),

                    onPressed: () async {
                      String email = emailController.text;
                      String password = passwordController.text;

                      try {
                        await _authService.login(
                          email: email,
                          password: password,
                        );
                        if (context.mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HomeScreen(),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error: ${e.toString()}")),
                          );
                        }
                      }
                    },

                    child: const Text("Login", style: TextStyle(fontSize: 18)),
                  ),
                ),

                const SizedBox(height: 20),

                /// REGISTER
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account?",
                      style: TextStyle(color: Colors.white70),
                    ),

                    TextButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                        if (result != null && result is String) {
                          emailController.text = result;
                        }
                      },
                      child: const Text("Register here"),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
