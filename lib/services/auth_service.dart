// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ================= Authentication =================
  // Current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  // Login user
  Future<String?> loginUser(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Register user
  Future<String?> registerUser(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Logout user
  Future<void> logout() async => await _auth.signOut();

  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  // Get user ID
  String? get userId => _auth.currentUser?.uid;

  // ================= Firestore User Data =================
  // Get complete user data from Firestore
  Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data();
    } catch (e) {
      print("Error fetching user data: $e");
      return null;
    }
  }

  // Get user role ('admin' or 'user')
  Future<String> getUserRole() async {
    final data = await getUserData();
    return data?['role'] ?? 'user';
  }

  // Get KYC status ('Pending' or 'Approved')
  Future<String> getKycStatus() async {
    final data = await getUserData();
    return data?['kycStatus'] ?? 'Pending';
  }

  // ================= Helpers =================
  // Check if user is admin
  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role.toLowerCase() == 'admin';
  }

  // Check if user KYC is approved
  Future<bool> isKycApproved() async {
    final status = await getKycStatus();
    return status.toLowerCase() == 'approved';
  }
}
