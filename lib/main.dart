import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'admin/admin_dashboard.dart';
import 'screens/verification_pending_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TravelDrop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData) {
          return const LoginPage();
        }
        return const UserRoleWrapper();
      },
    );
  }
}

class UserRoleWrapper extends StatefulWidget {
  const UserRoleWrapper({super.key});
  @override
  State<UserRoleWrapper> createState() => _UserRoleWrapperState();
}

class _UserRoleWrapperState extends State<UserRoleWrapper> {
  final AuthService _authService = AuthService();
  bool _loading = true;
  String? _role;
  String? _kycStatus;
  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final role = await _authService.getUserRole();
      final kyc = await _authService.getKycStatus();
      setState(() {
        _role = role.toLowerCase();
        _kycStatus = kyc.toLowerCase();
        _loading = false;
      });
    } catch (e) {
      print("Error loading role/KYC: $e");
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_role == 'admin') {
      return const AdminDashboard();
    }
    if (_role == 'user' && _kycStatus == 'approved') {
      return const HomePage();
    }

    return const VerificationPendingPage();
  }
}
