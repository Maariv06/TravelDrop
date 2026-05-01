import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_page.dart';

class VerificationPendingPage extends StatelessWidget {
  const VerificationPendingPage({super.key});

  void _showDialog(
    BuildContext context,
    String title,
    String content, {
    VoidCallback? onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          if (onConfirm != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onConfirm();
              },
              child: const Text("Check Now"),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Account Verification",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E4ABF),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.orange.shade200, width: 3),
              ),
              child: const Icon(
                Icons.pending_actions,
                size: 60,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Verification In Progress",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              "Your KYC verification is currently under review by our team",
              style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade100.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.hourglass_empty,
                    size: 40,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Under Review",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We are verifying your documents. This usually takes 24-48 hours.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade700,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildStep(
              Icons.upload_file,
              "Document Upload",
              "We've received your documents",
              Colors.green,
            ),
            _buildStep(
              Icons.verified_user,
              "Under Review",
              "Our team is verifying your details",
              Colors.orange,
              isActive: true,
            ),
            _buildStep(
              Icons.check_circle,
              "Approval",
              "You'll get access to all features",
              Colors.grey.shade400,
            ),
            const SizedBox(height: 40),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade50, Colors.blue.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                children: [
                  const Icon(Icons.help_center, size: 40, color: Colors.purple),
                  const SizedBox(height: 12),
                  const Text(
                    "Need Help?",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Our support team is here to help you with any questions about the verification process.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.purple,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  _contactRow(
                    Icons.email,
                    "support@traveldrop.com",
                    Colors.purple.shade600,
                  ),
                  _contactRow(
                    Icons.phone,
                    "+91-XXXXX-XXXXX",
                    Colors.purple.shade600,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text("Check Verification Status"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: () => _showDialog(
                context,
                "Check Status",
                "We'll check if your verification status has been updated. You'll be automatically redirected once approved.",
                onConfirm: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Checking verification status..."),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, // <-- Make full width
              child: OutlinedButton(
                onPressed: () => _showDialog(
                  context,
                  "Contact Support",
                  "Get in touch with our support team:\n\nEmail: support@traveldrop.com\nPhone: +91-98765-43210\nWhatsApp: +91-98765-43210\nWorking Hours: Mon-Sun, 9 AM - 6 PM",
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
                child: const Text(
                  "Contact Support",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(
    IconData icon,
    String title,
    String desc,
    Color color, {
    bool isActive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.2) : Colors.grey.shade200,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? color : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? color : Colors.grey.shade400,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? color : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
