import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'notification_services.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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

    String role = 'student'; // Default role
    if (userDoc.exists) {
      Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
      role = data['role'] ?? 'student';
    }

    // Update FCM token after successful login
    try {
      final notificationService = NotificationService();
      await notificationService.updateTokenAfterLogin();
    } catch (e) {
      print('Error updating FCM token after login: $e');
      // Don't throw - login should succeed even if token update fails
    }

    return role;
  }

  /// LOGOUT
  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      // Google Sign-In may fail on web if clientId is not configured.
      // This is safe to ignore — Firebase sign-out will still proceed.
      print('Google sign-out skipped: $e');
    }
    await _auth.signOut();
  }

  /// LOGIN WITH GOOGLE
  Future<String> loginWithGoogle() async {
    // Trigger Google Sign-In flow
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');

    // Get auth credentials
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user!;

    // Create or update user document in Firestore
    final userDoc = await _db.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      // New user - create document
      await _db.collection('users').doc(user.uid).set({
        'name': user.displayName ?? 'Google User',
        'email': user.email ?? '',
        'avatar': user.photoURL,
        'studentId': '',
        'role': 'student',
        'phone': null,
        'isActive': true,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    }

    // Get role
    final doc = await _db.collection('users').doc(user.uid).get();
    final role = (doc.data()?['role'] as String?) ?? 'student';

    // Update FCM token
    try {
      await NotificationService().updateTokenAfterLogin();
    } catch (e) {
      print('Error updating FCM token after Google login: $e');
    }

    return role;
  }

  /// SEND PASSWORD RESET EMAIL
  Future<void> sendPasswordReset({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
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
