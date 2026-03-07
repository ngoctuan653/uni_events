import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/storage_services.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  final _formKey = GlobalKey<FormState>();

  String? name;
  String? studentId;
  String? phone;
  String? faculty;
  String? bio;
  String? history;
  String? introduction;
  String? _currentAvatarUrl;
  File? _selectedImage;
  bool _isLoading = true;
  bool _isSaving = false;
  String _userRole = 'student';

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
          bio = data['bio'];
          history = data['history'];
          introduction = data['introduction'];
          _currentAvatarUrl = data['avatar'];
          _userRole = data['role'] ?? 'student';
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAvatar() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
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
        // Upload avatar if a new one was selected
        String? avatarUrl = _currentAvatarUrl;
        if (_selectedImage != null) {
          final uploadedUrl = await _storageService.uploadImage(
            _selectedImage!,
            'avatars',
          );
          if (uploadedUrl != null) {
            avatarUrl = uploadedUrl;
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Avatar upload failed. Saving without new avatar.',
                  ),
                ),
              );
            }
          }
        }

        Map<String, dynamic> updateData = {
          'name': name,
          'updatedAt': Timestamp.now(),
        };

        // Add role-specific fields
        if (_userRole == 'club') {
          updateData['bio'] = bio;
          updateData['history'] = history;
          updateData['introduction'] = introduction;
        } else {
          updateData['studentId'] = studentId;
          updateData['phone'] = phone;
          updateData['faculty'] = faculty;
        }

        if (avatarUrl != null) {
          updateData['avatar'] = avatarUrl;
        }

        await _db.collection('users').doc(currentUser.uid).update(updateData);

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
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
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
              // ─── Avatar Picker ───
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      _buildAvatarWidget(),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Tap to change avatar',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ),
              const SizedBox(height: 32),

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

              // Show different fields based on role
              if (_userRole == 'club') ...[
                _buildTextField(
                  label: 'Bio',
                  initialValue: bio,
                  icon: Icons.info_outline,
                  maxLines: 2,
                  onSaved: (value) => bio = value,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  label: 'Lịch sử CLB',
                  initialValue: history,
                  icon: Icons.history,
                  maxLines: 5,
                  onSaved: (value) => history = value,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  label: 'Giới thiệu CLB',
                  initialValue: introduction,
                  icon: Icons.description,
                  maxLines: 5,
                  onSaved: (value) => introduction = value,
                ),
              ] else ...[
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
              ],
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
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

  Widget _buildAvatarWidget() {
    if (_selectedImage != null) {
      // Show newly picked local image
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: FileImage(_selectedImage!),
      );
    } else if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) {
      // Show existing network avatar
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: NetworkImage(_currentAvatarUrl!),
      );
    } else {
      // Show default placeholder
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey.shade200,
        child: const Icon(Icons.person, size: 50, color: Colors.grey),
      );
    }
  }

  Widget _buildTextField({
    required String label,
    String? initialValue,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLines,
    required void Function(String?) onSaved,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      initialValue: initialValue,
      style: const TextStyle(color: Colors.black87),
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        prefixIcon: Icon(icon, color: Colors.orange),
        filled: true,
        fillColor: Colors.grey.shade100,
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
          borderSide: const BorderSide(color: Colors.orange, width: 1),
        ),
      ),
      onSaved: onSaved,
      validator: validator,
    );
  }
}
