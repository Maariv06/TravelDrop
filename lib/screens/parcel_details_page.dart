import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ParcelDetailsPage extends StatefulWidget {
  final String orderId;
  final bool isAssignedTraveler;
  final bool showTracking;

  const ParcelDetailsPage({
    required this.orderId,
    required this.isAssignedTraveler,
    this.showTracking = false,
    super.key,
  });

  @override
  State<ParcelDetailsPage> createState() => _ParcelDetailsPageState();
}

class _ParcelDetailsPageState extends State<ParcelDetailsPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // ================= Update Parcel Status =================
  Future<void> _updateStatus(
    String newStatus,
    String currentStatus, {
    String? otp,
  }) async {
    if (newStatus == currentStatus) return;

    final docRef = FirebaseFirestore.instance
        .collection('parcels')
        .doc(widget.orderId);

    try {
      if (newStatus == 'Delivered') {
        if (otp == null || otp.isEmpty) {
          throw Exception("OTP is required for delivery confirmation.");
        }

        final doc = await docRef.get();
        final correctOtp = doc.data()?['deliveryOtp'] ?? '1234';

        if (correctOtp == otp) {
          await docRef.update({
            'status': newStatus,
            'deliveredAt': FieldValue.serverTimestamp(),
          });
        } else {
          throw Exception("Invalid OTP. Delivery not confirmed.");
        }
      } else if (newStatus == 'Pending') {
        await docRef.update({
          'status': 'Pending',
          'assignedTravelerId': FieldValue.delete(),
          'assignedTravelerName': FieldValue.delete(),
          'assignedTravelerPhone': FieldValue.delete(),
        });
      } else {
        await docRef.update({'status': newStatus});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $newStatus!')),
        );
        if (newStatus == 'Pending' || newStatus == 'Delivered') {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: ${e.toString()}')),
        );
      }
    }
  }

  // ================= OTP Dialog =================
  void _showOtpDialog(String currentStatus) {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delivery'),
        content: TextField(
          controller: otpController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Enter Delivery OTP'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(
                'Delivered',
                currentStatus,
                otp: otpController.text.trim(),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // ================= Cancel Dialog =================
  void _showCancelDialog(String currentStatus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Assignment'),
        content: const Text(
          'Are you sure you want to cancel the assignment? The parcel will revert to the All Parcels list (Pending status).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus('Pending', currentStatus);
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  // ================= Status Order Helper =================
  int _statusOrder(String status) {
    switch (status) {
      case "Posted":
        return 1;
      case "Pending":
        return 2;
      case "Assigned":
        return 3;
      case "In Transit":
        return 4;
      case "Delivered":
        return 5;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Parcel Details',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E4ABF),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('parcels')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'Pending';
          final isOwner = data['createdBy'] == currentUser?.uid;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔹 Sender Information Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Sender Information",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E4ABF),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            "Name",
                            data['createdByName'] ?? 'N/A',
                          ),
                          _buildDetailRow(
                            "Mobile",
                            data['senderContact'] ?? 'N/A',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🔹 Receiver Information Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Receiver Information",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E4ABF),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            "Name",
                            data['receiverName'] ?? 'N/A',
                          ),
                          _buildDetailRow(
                            "Mobile",
                            data['receiverContact'] ?? 'N/A',
                          ),
                          _buildDetailRow(
                            "Address",
                            data['dropLocation'] ?? 'N/A',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🔹 Traveler Information Card (if assigned)
                  if (data['assignedTravelerName'] != null)
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Traveler Information",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildDetailRow(
                              "Name",
                              data['assignedTravelerName'] ?? 'N/A',
                            ),
                            _buildDetailRow(
                              "Mobile",
                              data['assignedTravelerPhone'] ?? 'N/A',
                            ),
                            _buildDetailRow("Status", "Assigned"),
                          ],
                        ),
                      ),
                    ),

                  if (data['assignedTravelerName'] != null)
                    const SizedBox(height: 16),

                  // 🔹 Parcel Details Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Parcel Details",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            "Pickup Location",
                            data['pickupLocation'] ?? 'N/A',
                          ),
                          _buildDetailRow(
                            "Drop Location",
                            data['dropLocation'] ?? 'N/A',
                          ),
                          _buildDetailRow(
                            "Weight",
                            "${data['weight'] ?? 'N/A'} kg",
                          ),
                          _buildDetailRow(
                            "Distance",
                            "${data['totalDistance']?.toStringAsFixed(1) ?? 'N/A'} km",
                          ),
                          _buildDetailRow(
                            "Price",
                            "₹${(data['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}",
                          ),
                          _buildDetailRow("Current Status", status),
                          if (data['expectedDeliveryDate'] != null)
                            _buildDetailRow(
                              "Expected Delivery",
                              "${data['expectedDeliveryDate'] ?? 'N/A'} ${data['expectedDeliveryTime'] ?? ''}",
                            ),
                          if (data['description'] != null &&
                              data['description'].toString().isNotEmpty)
                            _buildDetailRow("Description", data['description']),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🔹 Tracking Timeline only if showTracking is true
                  if (widget.showTracking)
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Tracking Timeline",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildTrackingStep("Posted", "Posted", status),
                            _buildTrackingStep("Assigned", "Assigned", status),
                            _buildTrackingStep(
                              "In Transit",
                              "In Transit",
                              status,
                            ),
                            _buildTrackingStep(
                              "Delivered",
                              "Delivered",
                              status,
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // --- Traveler Actions ---
                  if (widget.isAssignedTraveler)
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              "Traveler Actions",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (status == 'Assigned' || status == 'In Transit')
                              _buildActionButton(
                                'Cancel Assignment',
                                Colors.red,
                                () => _showCancelDialog(status),
                              ),
                            const SizedBox(height: 10),
                            if (status == 'Assigned')
                              _buildActionButton(
                                'Mark as In Transit',
                                Colors.orange.shade800,
                                () => _updateStatus('In Transit', status),
                              ),
                            if (status == 'In Transit')
                              _buildActionButton(
                                'Confirm Delivery (OTP)',
                                Colors.green.shade700,
                                () => _showOtpDialog(status),
                              ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.w500,
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
  }

  Widget _buildTrackingStep(
    String title,
    String checkStatus,
    String currentStatus,
  ) {
    // ✅ Always mark "Posted" as completed
    final isCompleted = title == "Posted"
        ? true
        : _statusOrder(checkStatus) <= _statusOrder(currentStatus);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? Colors.green : Colors.grey.shade400,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                color: isCompleted ? Colors.green : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _applyAsTraveler(
    String orderId,
    Map<String, dynamic> parcelData,
  ) async {
    final user = currentUser;
    if (user == null) return;

    final travelerName = "Traveler ${user.uid.substring(0, 4)}";
    final travelerContact = "N/A";

    await FirebaseFirestore.instance
        .collection('parcels')
        .doc(orderId)
        .collection('applications')
        .doc(user.uid)
        .set({
          'travelerId': user.uid,
          'travelerName': travelerName,
          'travelerContact': travelerContact,
          'status': 'Pending',
          'appliedAt': FieldValue.serverTimestamp(),
        });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Applied successfully! Owner will review.'),
        ),
      );
    }
  }

  Widget _buildApplicationsList(String orderId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('parcels')
          .doc(orderId)
          .collection('applications')
          .orderBy('appliedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final apps = snapshot.data!.docs;
        if (apps.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'No applications yet.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: apps.length,
          itemBuilder: (context, index) {
            final app = apps[index];
            final appData = app.data() as Map<String, dynamic>;
            final travelerId = appData['travelerId'] ?? 'unknown';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.person, color: Colors.blue),
                title: Text(
                  appData['travelerName'] ?? 'Unknown Traveler',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "Contact: ${appData['travelerContact'] ?? 'N/A'}",
                ),
                trailing: ElevatedButton(
                  onPressed: () async {
                    // Accept Application
                    await FirebaseFirestore.instance
                        .collection('parcels')
                        .doc(orderId)
                        .collection('applications')
                        .doc(app.id)
                        .update({'status': 'Accepted'});

                    // Assign Traveler
                    await FirebaseFirestore.instance
                        .collection('parcels')
                        .doc(orderId)
                        .update({
                          'status': 'Assigned',
                          'assignedTravelerId': travelerId,
                          'assignedTravelerName': appData['travelerName'],
                          'assignedTravelerPhone': appData['travelerContact'],
                        });

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Traveler Assigned!')),
                      );
                      setState(() {});
                    }
                  },
                  child: const Text('ACCEPT'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
