import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportManagementTab extends StatefulWidget {
  const ReportManagementTab({super.key});

  @override
  State<ReportManagementTab> createState() => _ReportManagementTabState();
}

class _ReportManagementTabState extends State<ReportManagementTab> {
  /// Fetch traveler data by ID
  Future<Map<String, dynamic>?> fetchTraveler(String travelerId) async {
    if (travelerId.isEmpty) return null;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(travelerId)
        .get();
    return doc.exists ? doc.data() : null;
  }

  /// Fetch parcel data by ID
  Future<Map<String, dynamic>?> fetchParcel(String parcelId) async {
    final doc = await FirebaseFirestore.instance
        .collection('parcels')
        .doc(parcelId)
        .get();
    return doc.exists ? doc.data() : null;
  }

  /// Show report details in bottom sheet
  void showReportDetails(Map<String, dynamic> report) async {
    final parcelId = report['parcelId'] ?? '';
    final parcel = await fetchParcel(parcelId);
    final traveler = parcel != null && parcel['assignedTravelerId'] != null
        ? await fetchTraveler(parcel['assignedTravelerId'])
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, ctl) => Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: ctl,
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
                  "Parcel ID: $parcelId",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Report Description:",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(report['reportDescription'] ?? 'N/A'),
                const SizedBox(height: 16),
                if (parcel != null) ...[
                  const Text(
                    "Sender & Receiver:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  _infoRow("Sender Name", parcel['createdByName']),
                  _infoRow("Sender Contact", parcel['senderContact']),
                  _infoRow("Receiver Name", parcel['receiverName']),
                  _infoRow("Receiver Contact", parcel['receiverContact']),
                  const SizedBox(height: 16),
                  if (traveler != null) ...[
                    const Text(
                      "Traveler Info:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    _infoRow("Name", traveler['name']),
                    _infoRow("Phone", traveler['phone']),
                    _infoRow("UPI ID", traveler['upiId']),
                  ] else
                    const Text("No traveler assigned or data unavailable"),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 120,
          child: Text("$label:", style: const TextStyle(color: Colors.grey)),
        ),
        Expanded(child: Text(value ?? 'N/A')),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .orderBy('reportedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "No reports found",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final reports = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index].data() as Map<String, dynamic>;
            final parcelId = report['parcelId'] ?? '';
            final shortParcelId = parcelId.length > 8
                ? "${parcelId.substring(0, 8)}..."
                : parcelId;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.report, color: Colors.red),
                title: Text("Parcel: $shortParcelId"),
                subtitle: Text(report['reportDescription'] ?? 'No description'),
                onTap: () => showReportDetails(report),
              ),
            );
          },
        );
      },
    );
  }
}
