import 'package:flutter/material.dart';
import '../services/auth_services.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final studentIdController = TextEditingController();
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
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),

                const SizedBox(height: 20),

                /// TITLE
                const Text(
                  "Register",
                  style: TextStyle(fontSize: 22, color: Colors.white),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Join the University Event Hub to discover and manage campus events.",
                  style: TextStyle(color: Colors.white70),
                ),

                const SizedBox(height: 30),

                /// FULL NAME
                const Text("Full Name", style: TextStyle(color: Colors.white)),
                const SizedBox(height: 8),

                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),

                  decoration: InputDecoration(
                    hintText: "e.g. Jane Doe",
                    hintStyle: const TextStyle(color: Colors.white54),

                    filled: true,
                    fillColor: const Color(0xFF1B263B),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// STUDENT ID
                const Text("Student ID", style: TextStyle(color: Colors.white)),
                const SizedBox(height: 8),

                TextField(
                  controller: studentIdController,
                  style: const TextStyle(color: Colors.white),

                  decoration: InputDecoration(
                    hintText: "e.g. 12345678",
                    hintStyle: const TextStyle(color: Colors.white54),

                    filled: true,
                    fillColor: const Color(0xFF1B263B),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// EMAIL
                const Text(
                  "University Email",
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),

                  decoration: InputDecoration(
                    hintText: "e.g. jane.doe@university.edu",
                    hintStyle: const TextStyle(color: Colors.white54),

                    filled: true,
                    fillColor: const Color(0xFF1B263B),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// PASSWORD
                const Text("Password", style: TextStyle(color: Colors.white)),
                const SizedBox(height: 8),

                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  style: const TextStyle(color: Colors.white),

                  decoration: InputDecoration(
                    hintText: "Enter a strong password",
                    hintStyle: const TextStyle(color: Colors.white54),

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

                const SizedBox(height: 30),

                /// CREATE ACCOUNT BUTTON
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
                      try {
                        await _authService.register(
                          name: nameController.text,
                          studentId: studentIdController.text,
                          email: emailController.text,
                          password: passwordController.text,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Account created successfully!"),
                            ),
                          );
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
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

                    child: const Text(
                      "Create Account",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// LOGIN
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Already have an account?",
                      style: TextStyle(color: Colors.white70),
                    ),

                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text("Log in"),
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
