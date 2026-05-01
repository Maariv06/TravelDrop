import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentManagementTab extends StatefulWidget {
  const PaymentManagementTab({super.key});

  @override
  State<PaymentManagementTab> createState() => _PaymentManagementTabState();
}

class _PaymentManagementTabState extends State<PaymentManagementTab> {
  Map<String, dynamic>? travelerData;

  Future<void> fetchTraveler(String travelerId) async {
    if (travelerId.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(travelerId)
        .get();
    if (doc.exists) travelerData = doc.data();
  }

  String _extractTamilNaduCity(dynamic loc) {
    if (loc == null) return 'N/A';
    if (loc is String) return _parseString(loc);
    if (loc is Map<String, dynamic>) {
      for (var key in ['city', 'locality', 'area', 'name', 'district']) {
        if (loc[key] is String && !_isState(loc[key])) return loc[key];
      }
      return loc['formattedAddress'] != null
          ? _parseString(loc['formattedAddress'])
          : 'N/A';
    }
    return 'N/A';
  }

  String _parseString(String str) {
    final parts = str.split(',').map((e) => e.trim()).toList();
    for (var i = parts.length - 1; i >= 0; i--) {
      final p = parts[i];
      if (p.isEmpty || _isState(p) || RegExp(r'\d').hasMatch(p) || p.length < 3)
        continue;
      return p;
    }
    return parts.isNotEmpty ? parts.last : str;
  }

  bool _isState(String name) =>
      ['tamil nadu', 'india'].contains(name.toLowerCase().trim());

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'in transit':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _paymentColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void showParcelDetails(Map<String, dynamic> parcel, String id) async {
    travelerData = null;
    if ((parcel['assignedTravelerId'] ?? '').isNotEmpty) {
      await fetchTraveler(parcel['assignedTravelerId']);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, ctl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: ctl,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  "Parcel ID: $id",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 12),
                _infoRow(
                  "Status",
                  parcel['status'] ?? 'N/A',
                  color: _statusColor(parcel['status']),
                ),
                _infoRow(
                  "Price",
                  "₹${parcel['price']?.toStringAsFixed(2) ?? '0'}",
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
                _infoRow(
                  "Pickup",
                  _extractTamilNaduCity(parcel['pickupLocation']),
                ),
                _infoRow("Drop", _extractTamilNaduCity(parcel['dropLocation'])),
                _infoRow("Weight", "${parcel['weight'] ?? 'N/A'} kg"),
                _infoRow("Description", parcel['description'] ?? 'N/A'),
                _infoRow(
                  "Distance",
                  "${parcel['totalDistance']?.toStringAsFixed(2) ?? '0'} km",
                ),
                _infoRow(
                  "Expected Date",
                  parcel['expectedDeliveryDate'] ?? 'N/A',
                ),
                _infoRow(
                  "Expected Time",
                  parcel['expectedDeliveryTime'] ?? 'N/A',
                ),
                _infoRow("Delivery OTP", parcel['deliveryOtp'] ?? 'N/A'),
                _infoRow(
                  "Payment Status",
                  parcel['paymentStatus'] ?? 'N/A',
                  color: _paymentColor(parcel['paymentStatus']),
                ),
                const SizedBox(height: 12),
                _contactSection(
                  "Sender",
                  parcel['createdByName'],
                  parcel['senderContact'],
                ),
                _contactSection(
                  "Receiver",
                  parcel['receiverName'],
                  parcel['receiverContact'],
                ),
                if (travelerData != null) ...[
                  const SizedBox(height: 12),
                  _contactSection(
                    "Traveler",
                    travelerData!['name'],
                    travelerData!['phone'],
                    extra: travelerData!['upiId'],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            "$label:",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: color ?? Colors.black,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _contactSection(
    String title,
    String? name,
    String? contact, {
    String? extra,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
      ),
      _infoRow("Name", name ?? 'N/A'),
      _infoRow("Contact", contact ?? 'N/A'),
      if (extra != null) _infoRow("UPI", extra),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('parcels').snapshots(),
      builder: (_, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final parcels = snap.data!.docs;
        if (parcels.isEmpty)
          return const Center(
            child: Text(
              "No parcels found",
              style: TextStyle(color: Colors.grey),
            ),
          );

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: parcels.length,
          itemBuilder: (_, i) {
            final parcel = parcels[i].data() as Map<String, dynamic>;
            final id = parcels[i].id;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _statusColor(
                    parcel['status'],
                  ).withOpacity(0.2),
                  child: Icon(
                    Icons.local_shipping,
                    color: _statusColor(parcel['status']),
                    size: 20,
                  ),
                ),
                title: Text(
                  "Parcel: ${id.substring(0, 8)}...",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  "${_extractTamilNaduCity(parcel['pickupLocation'])} → ${_extractTamilNaduCity(parcel['dropLocation'])}",
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "₹${parcel['price']?.toStringAsFixed(2) ?? '0'}",
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      parcel['paymentStatus'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: 10,
                        color: _paymentColor(parcel['paymentStatus']),
                      ),
                    ),
                  ],
                ),
                onTap: () => showParcelDetails(parcel, id),
              ),
            );
          },
        );
      },
    );
  }
}
