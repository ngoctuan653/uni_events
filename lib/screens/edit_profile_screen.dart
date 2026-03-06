import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  String? name;
  String? studentId;
  String? phone;
  String? faculty;
  bool _isLoading = true;
  bool _isSaving = false;

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
          name = data['name'];
          studentId = data['studentId'];
          phone = data['phone'];
          faculty = data['faculty'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isSaving = true;
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _db.collection('users').doc(currentUser.uid).update({
          'name': name,
          'studentId': studentId,
          'phone': phone,
          'faculty': faculty,
          'updatedAt': Timestamp.now(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
          Navigator.pop(context, true); // Return true to refresh profile screen
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF111827),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade800,
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              _buildTextField(
                label: 'Full Name',
                initialValue: name,
                icon: Icons.person,
                onSaved: (value) => name = value,
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter your name'
                    : null,
              ),
              const SizedBox(height: 20),

              _buildTextField(
                label: 'Student ID',
                initialValue: studentId,
                icon: Icons.badge,
                onSaved: (value) => studentId = value,
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter your student ID'
                    : null,
              ),
              const SizedBox(height: 20),

              _buildTextField(
                label: 'Phone Number',
                initialValue: phone,
                icon: Icons.phone_android,
                keyboardType: TextInputType.phone,
                onSaved: (value) => phone = value,
              ),
              const SizedBox(height: 20),

              _buildTextField(
                label: 'Faculty',
                initialValue: faculty,
                icon: Icons.school,
                onSaved: (value) => faculty = value,
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    String? initialValue,
    required IconData icon,
    TextInputType? keyboardType,
    required void Function(String?) onSaved,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      initialValue: initialValue,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        filled: true,
        fillColor: const Color(0xFF1F2937),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 1),
        ),
      ),
      onSaved: onSaved,
      validator: validator,
    );
  }
}
