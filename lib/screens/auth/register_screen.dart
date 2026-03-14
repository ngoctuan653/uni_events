import 'package:flutter/material.dart';
import '../../services/auth_services.dart';
import '../auth/login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final studentIdController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool obscurePassword = true;
  bool _isLoading = false;

  // Per-field Firebase error overrides
  String? _emailError;
  String? _passwordError;

  InputDecoration _fieldDecoration({required String hint, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  String? _parseFirebaseError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('email-already-in-use'))
      return 'This email is already registered.';
    if (msg.contains('invalid-email')) return 'Invalid email address.';
    if (msg.contains('weak-password'))
      return 'Password is too weak (min 6 characters).';
    if (msg.contains('network-request-failed'))
      return 'Network error. Check your connection.';
    return null;
  }

  Future<void> _submit() async {
    // Clear previous Firebase errors
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.register(
        name: nameController.text.trim(),
        studentId: studentIdController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account created successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('email-already-in-use') ||
          msg.contains('invalid-email')) {
        setState(() => _emailError = _parseFirebaseError(e));
      } else if (msg.contains('weak-password')) {
        setState(() => _passwordError = _parseFirebaseError(e));
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_parseFirebaseError(e) ?? e.toString())),
          );
        }
      }
      // Re-validate to show the new errors inline
      _formKey.currentState!.validate();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Create Account",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Join the University Event Hub to discover and manage campus events.",
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 30),

                  /// FULL NAME
                  _label("Full Name"),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.black87),
                    decoration: _fieldDecoration(hint: "e.g. Jane Doe"),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Name is required.';
                      if (v.trim().length < 2)
                        return 'Name must be at least 2 characters.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  /// STUDENT ID
                  _label("Student ID"),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: studentIdController,
                    style: const TextStyle(color: Colors.black87),
                    decoration: _fieldDecoration(hint: "e.g. 12345678"),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Student ID is required.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  /// EMAIL
                  _label("University Email"),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.black87),
                    decoration: _fieldDecoration(
                      hint: "e.g. jane.doe@university.edu",
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Email is required.';
                      if (!v.trim().contains('@') || !v.trim().contains('.'))
                        return 'Enter a valid email address.';
                      if (_emailError != null) return _emailError;
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  /// PASSWORD
                  _label("Password"),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    style: const TextStyle(color: Colors.black87),
                    decoration: _fieldDecoration(
                      hint: "Enter a strong password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.black45,
                        ),
                        onPressed: () =>
                            setState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty)
                        return 'Password is required.';
                      if (v.length < 6)
                        return 'Password must be at least 6 characters.';
                      if (_passwordError != null) return _passwordError;
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),

                  /// SUBMIT
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Create Account",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  /// LOGIN LINK
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Already have an account?",
                        style: TextStyle(color: Colors.black54),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Log in",
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
  );
}
