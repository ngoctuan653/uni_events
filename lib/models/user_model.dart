import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String studentId;
  final String role;
  final String? avatar;
  final String? phone;
  final String? faculty;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.studentId,
    required this.role,
    this.avatar,
    this.phone,
    this.faculty,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      studentId: data['studentId'] ?? '',
      role: data['role'] ?? 'student',
      avatar: data['avatar'],
      phone: data['phone'],
      faculty: data['faculty'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'studentId': studentId,
      'role': role,
      'avatar': avatar,
      'phone': phone,
      'faculty': faculty,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}
