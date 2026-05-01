import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';

Color _statusColor(String status) =>
    {'approved': Colors.green, 'rejected': Colors.red}[status.toLowerCase()] ??
    Colors.orange;

IconData _statusIcon(String status) =>
    {'approved': Icons.verified, 'rejected': Icons.cancel}[status
        .toLowerCase()] ??
    Icons.pending;

class UserManagementTab extends StatelessWidget {
  const UserManagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'user')
          .snapshots(),
      builder: (c, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final users = s.data!.docs;
        if (users.isEmpty)
          return const Center(
            child: Text('No users found', style: TextStyle(color: Colors.grey)),
          );
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          itemBuilder: (_, i) {
            final u = users[i].data() as Map<String, dynamic>;
            final kyc = (u['kycStatus'] ?? 'pending').toLowerCase();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _statusColor(kyc).withOpacity(0.2),
                  child: Icon(Icons.person, color: _statusColor(kyc)),
                ),
                title: Text(
                  u['name'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  u['email'] ?? 'No email',
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: Chip(
                  label: Text(
                    kyc.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(kyc),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: _statusColor(kyc).withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: _statusColor(kyc).withOpacity(0.5)),
                  ),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        UserDetailsPage(userId: users[i].id, initialUser: u),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class UserDetailsPage extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> initialUser;
  const UserDetailsPage({
    super.key,
    required this.userId,
    required this.initialUser,
  });

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  final _firestore = FirebaseFirestore.instance;

  Future<void> _updateKyc(
    BuildContext context,
    String status, {
    String? reason,
  }) async {
    final data = {
      'kycStatus': status,
      'kycUpdatedAt': FieldValue.serverTimestamp(),
      if (status == 'approved') 'kycApprovedAt': FieldValue.serverTimestamp(),
      if (status == 'approved') 'kycRejectReason': FieldValue.delete(),
      if (status == 'rejected' && reason != null) 'kycRejectReason': reason,
      if (status == 'rejected') 'kycApprovedAt': FieldValue.delete(),
    };
    try {
      await _firestore.collection('users').doc(widget.userId).update(data);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "KYC ${status.toUpperCase()}${reason != null ? ': $reason' : ''}",
            ),
            backgroundColor: (status == 'approved')
                ? Colors.green
                : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating KYC: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadImage(BuildContext context, String url) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = url.split('/').last.split('?').first;
      final filePath = "${dir.path}/$fileName";
      await Dio().download(url, filePath);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Image downloaded to documents folder"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Download failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRejectDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reject KYC"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: "Reason for rejection"),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = ctrl.text.trim();
              if (reason.isNotEmpty) {
                _updateKyc(context, "rejected", reason: reason);
                Navigator.pop(context);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please enter a rejection reason"),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Reject"),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            "$label:",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value?.toString() ?? 'N/A',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').doc(widget.userId).snapshots(),
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        if (!s.hasData || !s.data!.exists)
          return Scaffold(
            appBar: AppBar(
              title: const Text("User Details"),
              backgroundColor: const Color(0xFF1E4ABF),
            ),
            body: const Center(child: Text('User not found')),
          );
        final user = s.data!.data() ?? widget.initialUser;
        final kyc = (user['kycStatus'] ?? 'pending').toLowerCase();
        final idImageUrl = user['idImageUrl'];
        final isApproved = kyc == 'approved';
        final isRejected = kyc == 'rejected';

        return Scaffold(
          appBar: AppBar(
            title: const Text("User Details"),
            backgroundColor: const Color(0xFF1E4ABF),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Personal Information",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E4ABF),
                          ),
                        ),
                        const Divider(height: 20),
                        _buildRow("Name", user['name']),
                        _buildRow("Email", user['email']),
                        _buildRow("Phone", user['phone']),
                        _buildRow("Address", user['address']),
                        _buildRow("ID Type", user['idType']),
                        _buildRow("ID Number", user['idNumber']),
                        const SizedBox(height: 10),
                        Chip(
                          label: Text('KYC Status: ${kyc.toUpperCase()}'),
                          avatar: Icon(
                            _statusIcon(kyc),
                            color: _statusColor(kyc),
                          ),
                          backgroundColor: _statusColor(kyc).withOpacity(0.1),
                        ),
                        if (isRejected && user['kycRejectReason'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _buildRow("Reason", user['kycRejectReason']),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "ID Document Image",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E4ABF),
                          ),
                        ),
                        const Divider(height: 20),
                        if (idImageUrl != null && idImageUrl.isNotEmpty)
                          Column(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FullscreenImageView(
                                      imageUrl: idImageUrl,
                                    ),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    idImageUrl,
                                    height: 250,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FullscreenImageView(
                                          imageUrl: idImageUrl,
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(Icons.zoom_in),
                                    label: const Text("Zoom"),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _downloadImage(context, idImageUrl),
                                    icon: const Icon(Icons.download),
                                    label: const Text("Download"),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              "No ID Image Submitted",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isApproved
                            ? null
                            : () => _updateKyc(context, "approved"),
                        icon: const Icon(Icons.check_circle),
                        label: const Text("Approve KYC"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isApproved
                              ? Colors.grey
                              : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isRejected
                            ? null
                            : () => _showRejectDialog(context),
                        icon: const Icon(Icons.cancel),
                        label: const Text("Reject KYC"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRejected
                              ? Colors.grey
                              : Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class FullscreenImageView extends StatelessWidget {
  final String imageUrl;
  const FullscreenImageView({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PhotoView(
        imageProvider: NetworkImage(imageUrl),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2,
        enableRotation: true,
      ),
    );
  }
}
