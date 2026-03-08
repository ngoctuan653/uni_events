import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PublicUserProfileScreen extends StatefulWidget {
  final String userId;

  const PublicUserProfileScreen({super.key, required this.userId});

  @override
  State<PublicUserProfileScreen> createState() =>
      _PublicUserProfileScreenState();
}

class _PublicUserProfileScreenState extends State<PublicUserProfileScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final doc = await _db.collection('users').doc(widget.userId).get();
      if (doc.exists) {
        setState(() {
          _userData = doc.data();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    if (_userData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Profile')),
        body: const Center(child: Text('User not found')),
      );
    }

    final name = _userData?['name'] ?? 'Unknown User';
    final studentId = _userData?['studentId'] ?? '';
    final role = _userData?['role'] ?? 'student';
    final faculty = _userData?['faculty'] ?? '';
    final phone = _userData?['phone'] ?? '';
    final email = _userData?['email'] ?? '';
    final avatar = _userData?['avatar'] as String?;
    final bio = _userData?['bio'] ?? '';

    // Generate initials for avatar fallback
    final initials = (name as String)
        .split(' ')
        .where((String w) => w.isNotEmpty)
        .take(2)
        .map((String w) => w[0].toUpperCase())
        .join();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.orange.shade200,
                    backgroundImage: (avatar != null && avatar.isNotEmpty)
                        ? NetworkImage(avatar)
                        : null,
                    child: (avatar == null || avatar.isEmpty)
                        ? Text(
                            initials,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: role == 'club'
                          ? Colors.blue.shade100
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: role == 'club'
                            ? Colors.blue.shade800
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Bio Section if available
            if (bio.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Text(
                  '"$bio"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),

            // Info Details Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ABOUT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard([
                    if (studentId.isNotEmpty)
                      _buildInfoRow(Icons.badge, 'Student ID', studentId),
                    if (faculty.isNotEmpty)
                      _buildInfoRow(Icons.school, 'Faculty', faculty),
                  ]),
                  const SizedBox(height: 24),
                  const Text(
                    'CONTACT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard([
                    if (email.isNotEmpty)
                      _buildInfoRow(Icons.email, 'Email', email),
                    if (phone.isNotEmpty)
                      _buildInfoRow(Icons.phone, 'Phone', phone),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();

    // Add dividers between rows
    final List<Widget> children = [];
    for (int i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i < rows.length - 1) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange.shade400, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
