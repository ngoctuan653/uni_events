import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// REGISTER
  Future<UserCredential> register({
    required String name,
    required String studentId,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    print("AUTH CREATED: ${credential.user!.uid}");

    await _db.collection("users").doc(credential.user!.uid).set({
      "name": name,
      "studentId": studentId,
      "email": email,
      "role": "student",
      "avatar": null,
      "phone": null,
      "isActive": true,
      "createdAt": Timestamp.now(),
      "updatedAt": Timestamp.now(),
    });
    print("FIRESTORE USER CREATED");
    return credential;
  }

  /// LOGIN
  Future<String> login({
    required String email,
    required String password,
  }) async {
    UserCredential credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Fetch user role
    DocumentSnapshot userDoc = await _db
        .collection('users')
        .doc(credential.user!.uid)
        .get();
    if (userDoc.exists) {
      Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
      return data['role'] ?? 'student';
    }
    return 'student'; // Default role
  }

  /// LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// GET USER ROLE
  Future<String> getUserRole(String uid) async {
    try {
      DocumentSnapshot userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        return data['role'] ?? 'student';
      }
    } catch (e) {
      print("Error fetching role: $e");
    }
    return 'student'; // Fallback
  }
}
