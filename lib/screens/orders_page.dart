import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'parcel_details_page.dart';
import 'create_order_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String searchQuery = "";
  int selectedTabIndex = 0; // 0: All Parcels, 1: Assigned

  // ---------------- Helper function to get clean area/city ----------------
  String _getCleanLocation(String fullLocation) {
    if (fullLocation.isEmpty) return "Unknown";
    final parts = fullLocation.split(',').map((s) => s.trim()).toList();
    for (final part in parts) {
      if (part.length > 3 &&
          !part.contains(RegExp(r'\d+')) && // remove numbers
          part.toLowerCase() != 'india' &&
          part.toLowerCase() != 'tamil nadu') {
        return part;
      }
    }
    return parts.isNotEmpty ? parts.first : fullLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Parcels", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E4ABF),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Tab Switcher
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E4ABF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildTabButton("All Parcels", 0),
                _buildTabButton("Assigned", 1),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Search parcels by pickup/drop location...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  searchQuery = val.toLowerCase();
                });
              },
            ),
          ),
          // Scrollable content
          Expanded(
            child: selectedTabIndex == 0
                ? _buildAllParcels()
                : _buildAssignedParcels(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        child: const Icon(Icons.add, color: Color(0xFF1E4ABF)),
        onPressed: _createNewParcel,
      ),
    );
  }

  // ================= Tab Button =================
  Widget _buildTabButton(String label, int index) {
    final isSelected = selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF1E4ABF) : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= All Parcels =================
  Widget _buildAllParcels() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("parcels")
          .where("status", isEqualTo: "Posted")
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        final filtered = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final pickup = (data['pickupLocation'] ?? "")
              .toString()
              .toLowerCase();
          final drop = (data['dropLocation'] ?? "").toString().toLowerCase();
          final createdBy = data['createdBy'] ?? "";
          return createdBy != currentUser?.uid &&
              (pickup.contains(searchQuery) || drop.contains(searchQuery));
        }).toList();

        if (filtered.isEmpty)
          return const Center(child: Text("No available parcels found"));

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final data = filtered[index].data() as Map<String, dynamic>;
            final docId = filtered[index].id;

            final pickup = _getCleanLocation(data['pickupLocation'] ?? "");
            final drop = _getCleanLocation(data['dropLocation'] ?? "");

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text("From: $pickup\nTo: $drop"),
                subtitle: Text(
                  "Weight: ${data['weight'] ?? "N/A"} kg | Price: ₹${data['price'] ?? "N/A"} | Distance: ${data['totalDistance']?.toStringAsFixed(1) ?? "N/A"} km",
                ),
                trailing: ElevatedButton(
                  onPressed: () => _applyParcel(docId, data),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E4ABF),
                  ),
                  child: const Text(
                    "Apply",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ParcelDetailsPage(
                      orderId: docId,
                      isAssignedTraveler: false,
                      showTracking: false,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ================= Assigned Parcels =================
  Widget _buildAssignedParcels() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("parcels")
          .where("assignedTravelerId", isEqualTo: currentUser?.uid)
          .where('status', whereIn: ['Assigned', 'In Transit'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        final filtered = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final pickup = (data['pickupLocation'] ?? "")
              .toString()
              .toLowerCase();
          final drop = (data['dropLocation'] ?? "").toString().toLowerCase();
          return pickup.contains(searchQuery) || drop.contains(searchQuery);
        }).toList();

        if (filtered.isEmpty)
          return const Center(child: Text("No active assigned parcels"));

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final data = filtered[index].data() as Map<String, dynamic>;
            final docId = filtered[index].id;

            final pickup = _getCleanLocation(data['pickupLocation'] ?? "");
            final drop = _getCleanLocation(data['dropLocation'] ?? "");

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text("From: $pickup\nTo: $drop"),
                subtitle: Text("Status: ${data['status'] ?? "Assigned"}"),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ParcelDetailsPage(
                      orderId: docId,
                      isAssignedTraveler: true,
                      showTracking: true,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ================= Apply for Parcel =================
  Future<void> _applyParcel(
    String docId,
    Map<String, dynamic> parcelData,
  ) async {
    final user = currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();
      final userData = userDoc.data();
      if (userData == null) return;

      final travelerName = userData['name'] ?? "Unknown";
      final travelerPhone = userData['phone'] ?? "N/A";

      await FirebaseFirestore.instance.collection("parcels").doc(docId).update({
        "status": "Assigned",
        "assignedTravelerId": user.uid,
        "assignedTravelerName": travelerName,
        "assignedTravelerPhone": travelerPhone,
      });

      await FirebaseFirestore.instance.collection("assigned").doc(docId).set({
        ...parcelData,
        "status": "Assigned",
        "assignedTravelerId": user.uid,
        "assignedTravelerName": travelerName,
        "assignedTravelerPhone": travelerPhone,
        "assignedAt": FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Parcel assigned to you")));
        setState(() {
          selectedTabIndex = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error assigning parcel: $e")));
      }
    }
  }

  // ================= Navigate to CreateOrderPage =================
  void _createNewParcel() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateOrderPage()),
    );
  }
}
