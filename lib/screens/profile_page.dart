import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'parcel_details_page.dart';
import 'login_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  // Fetch user data from Firestore
  Future<Map<String, dynamic>?> _getUserInfo(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .get();
    return doc.data();
  }

  // Simplify location display
  String _getCleanLocation(String fullLocation) {
    if (fullLocation.isEmpty || fullLocation == 'N/A') return 'N/A';
    final parts = fullLocation.split(',').map((s) => s.trim()).toList();
    for (final part in parts) {
      if (part.length > 3 &&
          !part.contains('+') &&
          !part.contains(RegExp(r'\d+')) &&
          part.toLowerCase() != 'india' &&
          part.toLowerCase() != 'tamil nadu') {
        return part;
      }
    }
    return parts.isNotEmpty
        ? parts.firstWhere((p) => p.isNotEmpty, orElse: () => fullLocation)
        : fullLocation;
  }

  // Delete parcel
  Future<void> _deleteParcel(
    BuildContext context,
    String parcelId,
    String status,
  ) async {
    if (status != 'Pending' && status != 'Posted') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Cannot delete: Parcel is already assigned, in transit, or delivered.",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Parcel"),
        content: const Text(
          "Are you sure you want to permanently delete this parcel order?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection("parcels")
            .doc(parcelId)
            .delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Parcel order deleted successfully!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to delete parcel: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Report parcel
  Future<void> _reportParcel(
    BuildContext context,
    String parcelId,
    Map<String, dynamic> parcelData,
  ) async {
    final TextEditingController _reasonController = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Report Parcel"),
        content: TextField(
          controller: _reasonController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: "Describe the issue with this parcel",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (_reasonController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("Submit"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final reasonText = _reasonController.text.trim();

    try {
      await FirebaseFirestore.instance.collection("reports").add({
        "parcelId": parcelId,
        "reportedByUid": FirebaseAuth.instance.currentUser!.uid,
        "reportedAt": FieldValue.serverTimestamp(),
        "reportDescription": reasonText,
        "parcelDetails": parcelData,
      });

      await FirebaseFirestore.instance
          .collection("parcels")
          .doc(parcelId)
          .update({"isReported": true});

      await FirebaseFirestore.instance.collection("notifications").add({
        "userId": FirebaseAuth.instance.currentUser!.uid,
        "title": "Parcel Report Submitted",
        "message": "Your report for parcel $parcelId has been submitted.",
        "createdAt": FieldValue.serverTimestamp(),
        "read": false,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Parcel reported successfully!"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to report parcel: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Logout and navigate to LoginPage
  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null)
      return const Scaffold(body: Center(child: Text("User not logged in")));

    return Scaffold(
      appBar: AppBar(
        // Profile title is now white
        title: const Text("Profile", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E4ABF),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("notifications")
                .where("userId", isEqualTo: user.uid)
                .where("read", isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              int unreadCount = snapshot.data?.docs.length ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsPage(),
                        ),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          "$unreadCount",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _logout(context); // simple void call
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getUserInfo(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data == null)
            return const Center(child: Text("Could not load user data."));

          final userData = snapshot.data!;
          final userName = userData["name"] ?? "User";
          final userPhone = userData["phone"] ?? "N/A";
          final userEmail = user.email ?? "N/A";
          final userUpiId = userData["upiId"] ?? "N/A";
          final userAddress = userData["address"] ?? "N/A";
          final kycStatus = userData["kycStatus"] ?? "Pending";

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                color: const Color(0xFF1E4ABF),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white,
                          child: Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : "U",
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      userName,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (kycStatus == "Approved")
                                    const Icon(
                                      Icons.verified,
                                      color: Colors.greenAccent,
                                      size: 20,
                                    ),
                                ],
                              ),
                              Text(
                                userEmail,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      "Mobile: $userPhone",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      "UPI ID: $userUpiId",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      "Address: $userAddress",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.only(left: 15.0, bottom: 8.0),
                child: Text(
                  "My Posted Parcels",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("parcels")
                      .where("createdBy", isEqualTo: user.uid)
                      .orderBy("createdAt", descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                      return const Center(
                        child: Text("No parcel orders found"),
                      );

                    final docs = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final parcelDoc = docs[index];
                        final data = parcelDoc.data() as Map<String, dynamic>;
                        final docId = parcelDoc.id;
                        final pickup = _getCleanLocation(
                          data['pickupLocation'] ?? "",
                        );
                        final drop = _getCleanLocation(
                          data['dropLocation'] ?? "",
                        );
                        final status = data['status'] ?? "Pending";
                        final isReported = data["isReported"] ?? false;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            title: Text(
                              "From: $pickup\nTo: $drop",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Status: $status",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: status == 'Delivered'
                                        ? Colors.green
                                        : Colors.blue,
                                  ),
                                ),
                                if (isReported)
                                  const Text(
                                    "Reported",
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'delete')
                                  _deleteParcel(context, docId, status);
                                if (value == 'report')
                                  _reportParcel(context, docId, data);
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'delete',
                                  enabled:
                                      status == 'Pending' || status == 'Posted',
                                  child: Text(
                                    "Delete",
                                    style: TextStyle(
                                      color:
                                          status == 'Pending' ||
                                              status == 'Posted'
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'report',
                                  child: Text("Report"),
                                ),
                              ],
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ParcelDetailsPage(
                                  orderId: docId,
                                  isAssignedTraveler: false,
                                  showTracking: true,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// NotificationsPage remains unchanged
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _notificationsRef = FirebaseFirestore.instance.collection(
    'notifications',
  );

  DateTime? _parseTimestamp(dynamic ts) {
    if (ts == null) return null;
    if (ts is Timestamp) return ts.toDate();
    if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
    if (ts is String) return DateTime.tryParse(ts);
    return null;
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return "$d/$m/$y $hh:$mm";
  }

  Future<void> _markAsRead(String docId) async {
    await _notificationsRef.doc(docId).update({'read': true});
  }

  Future<void> _markAllRead(List<String> docIds) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final id in docIds)
      batch.update(_notificationsRef.doc(id), {'read': true});
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null)
      return const Scaffold(body: Center(child: Text("User not logged in")));

    return Scaffold(
      appBar: AppBar(
        // Notifications title is now white
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E4ABF),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notificationsRef
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            return const Center(child: Text("No notifications yet"));

          final items = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final DateTime? dt = _parseTimestamp(data['createdAt']);
            return {
              'id': doc.id,
              'title': data['title'] ?? 'Notification',
              'message': data['message'] ?? '',
              'time': dt,
              'read': data['read'] ?? false,
            };
          }).toList();

          items.sort((a, b) {
            final aTime = a['time'] as DateTime?;
            final bTime = b['time'] as DateTime?;
            return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
              aTime?.millisecondsSinceEpoch ?? 0,
            );
          });

          final unreadIds = items
              .where((i) => i['read'] == false)
              .map((i) => i['id'] as String)
              .toList();

          return Column(
            children: [
              if (unreadIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${unreadIds.length} unread",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _markAllRead(unreadIds),
                        child: const Text("Mark all read"),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final it = items[index];
                    final dt = it['time'] as DateTime?;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: Icon(
                          it['read']
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                          color: it['read'] ? Colors.grey : Colors.blue,
                        ),
                        title: Text(
                          it['title'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it['message'] as String),
                            if (dt != null)
                              Text(
                                _formatDateTime(dt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                        trailing: it['read']
                            ? null
                            : IconButton(
                                icon: const Icon(
                                  Icons.check,
                                  color: Colors.green,
                                ),
                                onPressed: () =>
                                    _markAsRead(it['id'] as String),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
