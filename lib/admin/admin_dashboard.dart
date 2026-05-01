import 'package:flutter/material.dart';
import 'user_management_tab.dart';
import 'payment_management_tab.dart';
import 'report_management_tab.dart';
import 'package:TravelDrop/screens/login_page.dart'; // Import your login page

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Only 3 tabs now
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Handle back button press
  Future<bool> _onWillPop() async {
    if (_tabController.index != 0) {
      setState(() {
        _tabController.index -= 1;
      });
      return false;
    }
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Exit App"),
        content: const Text("Are you sure you want to exit?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  // Logout and redirect to LoginPage
  void _logout() async {
    final confirmLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (confirmLogout ?? false) {
      // If using Firebase Auth, uncomment below
      // await FirebaseAuth.instance.signOut();

      // Navigate to LoginPage and remove all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            "Admin Dashboard",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF1E4ABF),
          centerTitle: true,
          elevation: 2,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _logout,
              tooltip: "Logout",
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicator: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.all(4),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            tabs: const [
              Tab(icon: Icon(Icons.people, size: 20), text: "Users"),
              Tab(icon: Icon(Icons.payment, size: 20), text: "Payments"),
              Tab(icon: Icon(Icons.assessment, size: 20), text: "Reports"),
            ],
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1E4ABF).withOpacity(0.1),
                Colors.grey[50]!,
              ],
            ),
          ),
          child: TabBarView(
            controller: _tabController,
            children: const [
              UserManagementTab(),
              PaymentManagementTab(),
              ReportManagementTab(),
            ],
          ),
        ),
      ),
    );
  }
}
