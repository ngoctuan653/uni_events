import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_services.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String name = "Loading...";
  String studentId = "Loading...";
  String email = "Loading...";
  String phone = "Not provided";
  String faculty = "Not provided";
  String? avatar;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      DocumentSnapshot userDoc = await _db
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          name = data['name'] ?? 'No Name';
          studentId = data['studentId'] ?? 'No ID';
          email = data['email'] ?? currentUser.email ?? 'No Email';
          phone = data['phone'] ?? 'Not provided';
          faculty = data['faculty'] ?? 'Not provided';
          avatar = data['avatar'];
        });
      }
    }
  }

  void _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827), // Darker background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Profile Picture
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey.shade800,
                backgroundImage: avatar != null ? NetworkImage(avatar!) : null,
                child: avatar == null
                    ? const Icon(Icons.person, size: 50, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 16),
              // Name
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              // Student ID under name
              Text(
                studentId,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 16),
              // Edit Profile Button
              SizedBox(
                width: 140,
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfileScreen(),
                      ),
                    );
                    if (result == true) {
                      _fetchUserData(); // Refresh data
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // PERSONAL INFORMATION Section
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PERSONAL INFORMATION',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.email, Colors.blue, 'Email', email),
                    _buildDivider(),
                    _buildInfoRow(
                      Icons.phone_android,
                      Colors.blue,
                      'Phone',
                      phone,
                    ),
                    _buildDivider(),
                    _buildInfoRow(
                      Icons.school,
                      Colors.blue,
                      'Faculty',
                      faculty,
                    ),
                    _buildDivider(),
                    _buildInfoRow(
                      Icons.badge,
                      Colors.blue,
                      'Student ID',
                      studentId,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // SETTINGS Section
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SETTINGS',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937), // Dark grayish blue
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildSettingsRow(Icons.notifications, 'Notifications'),
                    _buildDivider(),
                    _buildSettingsRow(Icons.lock, 'Privacy & Security'),
                    _buildDivider(),
                    _buildSettingsRow(Icons.help_outline, 'Help & Support'),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide.none,
                    backgroundColor: const Color(0xFF1F2937),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1F2937),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        currentIndex: 3, // Profile is selected
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number),
            label: 'Tickets',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    Color iconBgColor,
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2C3E50), // slightly lighter
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 18),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsRow(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2C3E50),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.grey.shade400, size: 18),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.grey.shade800, height: 1, thickness: 1);
  }
}
