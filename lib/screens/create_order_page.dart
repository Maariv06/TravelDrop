import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'location_picker_map.dart';

/// =======================
/// PAYMENT PAGE
/// =======================
class PaymentPage extends StatelessWidget {
  final double amount;
  final String upiId;
  final String parcelId;
  final String otp;

  const PaymentPage({
    super.key,
    required this.amount,
    required this.upiId,
    required this.parcelId,
    required this.otp,
  });

  Future<void> _markPayment(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser!;
    try {
      await FirebaseFirestore.instance
          .collection("parcels")
          .doc(parcelId)
          .update({"paymentStatus": "Paid"});

      await FirebaseFirestore.instance.collection("notifications").add({
        "userId": user.uid,
        "title": "Payment Successful",
        "message":
            "Your payment of ₹${amount.toStringAsFixed(0)} was successful. Your OTP is $otp. Share this OTP with traveler only during delivery.",
        "createdAt": FieldValue.serverTimestamp(),
        "read": false,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Parcel Posted successfully."),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate back to the main screen (home)
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error saving payment: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Note: The amount for UPI string must be accurate, but we use the rounded value here
    final upiString =
        "upi://pay?pa=$upiId&pn=TravelDrop%20Payments&am=${amount.toStringAsFixed(0)}&cu=INR";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Complete Payment"),
        backgroundColor: const Color(0xFF1E4ABF),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.payment, size: 60, color: Color(0xFF1E4ABF)),
              const SizedBox(height: 20),
              Text(
                "Pay ₹${amount.toStringAsFixed(0)}", // Display as rounded integer
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Scan this QR to pay to: $upiId",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              QrImageView(
                data: upiString,
                version: QrVersions.auto,
                size: 220.0,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => _markPayment(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  "Paid",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// =======================
/// CREATE ORDER PAGE
/// =======================
class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({super.key});

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  static const String BUSINESS_UPI_ID = "mariappan.29062003@okaxis";

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _senderContactController =
      TextEditingController();
  final TextEditingController _receiverNameController = TextEditingController();
  final TextEditingController _receiverContactController =
      TextEditingController();
  final TextEditingController _expectedDateController = TextEditingController();
  final TextEditingController _expectedTimeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  File? _parcelImage;
  bool _isLoading = false;
  double totalDistance = 0.0;
  // **CHANGED: price is now an integer for rounded pricing**
  int price = 0;
  String otp = "";

  LatLng? _pickupLocation;
  LatLng? _dropLocation;
  String? _pickupAddress;
  String? _dropAddress;

  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _weightController.addListener(_updatePrice);
  }

  @override
  void dispose() {
    _weightController.removeListener(_updatePrice); // Remove listener
    _weightController.dispose();
    _pickupController.dispose();
    _dropController.dispose();
    _senderContactController.dispose();
    _receiverNameController.dispose();
    _receiverContactController.dispose();
    _expectedDateController.dispose();
    _expectedTimeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) {
      setState(() => _parcelImage = File(picked.path));
    }
  }

  double _getWeightSurcharge(int weightKg) {
    if (weightKg >= 7) return 100.0;
    if (weightKg >= 5) return 75.0;
    if (weightKg >= 3) return 50.0;
    return 20.0;
  }

  double _calculateDistanceCharge(double distanceKm) {
    const double tier1Rate = 1.0;
    const double tier2Rate = 0.5;
    const double tier1Limit = 20.0;
    if (distanceKm <= tier1Limit) return distanceKm * tier1Rate;
    return tier1Limit * tier1Rate + (distanceKm - tier1Limit) * tier2Rate;
  }

  void _updatePrice() {
    final weightKg = int.tryParse(_weightController.text);
    const double baseFare = 35.0;
    if (_pickupLocation != null &&
        _dropLocation != null &&
        weightKg != null &&
        weightKg > 0 &&
        weightKg <= 10) {
      final distanceKm = _calculateDistance(
        _pickupLocation!.latitude,
        _pickupLocation!.longitude,
        _dropLocation!.latitude,
        _dropLocation!.longitude,
      );
      final distanceCharge = _calculateDistanceCharge(distanceKm);
      final weightSurcharge = _getWeightSurcharge(weightKg);

      // Calculate the floating point price
      final double calculatedPrice =
          baseFare + distanceCharge + weightSurcharge;

      setState(() {
        totalDistance = distanceKm;
        // **UPDATED: Round the final price to the nearest integer**
        price = calculatedPrice.round();
      });
    } else {
      setState(() {
        totalDistance = 0.0;
        price = 0;
      });
    }
  }

  String _generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<void> _sendOTP(String phone, String otp) async {
    // In a real application
    print("OTP SENT to $phone: $otp");
    // Simulate a small delay for the "send" operation
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _scheduleParcelExpiry(
    String parcelId,
    DateTime expectedTime,
  ) async {
    final now = DateTime.now();
    Duration untilExpiry = expectedTime.difference(now);
    if (untilExpiry.isNegative) untilExpiry = Duration.zero;

    // We might want to set a minimum threshold, e.g., 5 minutes,
    // or cap the max timer duration for cloud stability.
    if (untilExpiry > const Duration(days: 30)) {
      untilExpiry = const Duration(days: 30);
    }

    Timer(untilExpiry, () async {
      // Check if the parcel has been assigned before expiring it
      final docSnapshot = await FirebaseFirestore.instance
          .collection("parcels")
          .doc(parcelId)
          .get();

      if (!docSnapshot.exists || docSnapshot.data()?["status"] != "Pending") {
        return; // Already handled (e.g., assigned or paid/cancelled)
      }

      try {
        final user = FirebaseAuth.instance.currentUser!;
        await FirebaseFirestore.instance
            .collection("parcels")
            .doc(parcelId)
            .update({"status": "Expired"}); // Change status to Expired

        await FirebaseFirestore.instance.collection("notifications").add({
          "userId": user.uid,
          "title": "Parcel Expired",
          "message":
              "Your parcel was not assigned and has expired. You may repost.",
          "createdAt": FieldValue.serverTimestamp(),
          "read": false,
        });

        // Optional cleanup: move to a separate 'expiredParcels' collection and delete the original
        Timer(const Duration(minutes: 15), () async {
          final doc = await FirebaseFirestore.instance
              .collection("parcels")
              .doc(parcelId)
              .get();
          if (doc.exists && doc.data()?["status"] == "Expired") {
            await FirebaseFirestore.instance
                .collection("expiredParcels")
                .doc(parcelId)
                .set(doc.data()!);
            await FirebaseFirestore.instance
                .collection("parcels")
                .doc(parcelId)
                .delete();
          }
        });
      } catch (e) {
        print("Error handling parcel expiry: $e");
      }
    });
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickupLocation == null || _dropLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select pickup and drop locations"),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? imageUrl;
      if (_parcelImage != null) {
        final ref = FirebaseStorage.instance.ref().child(
          "parcels/${DateTime.now().millisecondsSinceEpoch}.jpg",
        );
        final uploadTask = await ref.putFile(_parcelImage!);
        imageUrl = await uploadTask.ref.getDownloadURL();
      }

      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();
      final createdByName = userDoc.data()?["name"] ?? "Unknown User";

      _updatePrice(); // Final price calculation
      if (price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Price calculation error. Check location/weight."),
          ),
        );
        return;
      }

      otp = _generateOTP();
      // Send OTP to the RECEIVER's contact number
      await _sendOTP(_receiverContactController.text.trim(), otp);

      // Parse date and time from controllers
      final dateParts = _expectedDateController.text.split('/');
      final timeParts = _expectedTimeController.text.split(':');
      final expectedDateTime = DateTime(
        int.parse(dateParts[2]),
        int.parse(dateParts[1]),
        int.parse(dateParts[0]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      final parcelRef = await FirebaseFirestore.instance
          .collection("parcels")
          .add({
            "pickupLocation": _pickupAddress,
            "dropLocation": _dropAddress,
            "pickupLatLng": {
              "latitude": _pickupLocation!.latitude,
              "longitude": _pickupLocation!.longitude,
            },
            "dropLatLng": {
              "latitude": _dropLocation!.latitude,
              "longitude": _dropLocation!.longitude,
            },
            "weight": int.parse(_weightController.text.trim()),
            "description": _descriptionController.text.trim(),
            "senderContact": _senderContactController.text.trim(),
            "receiverName": _receiverNameController.text.trim(),
            "receiverContact": _receiverContactController.text.trim(),
            "parcelImageUrl": imageUrl,
            "totalDistance": totalDistance,
            // **UPDATED: Store price as the rounded integer value**
            "price": price,
            "deliveryOtp": otp,
            "status": "Posted", // Status starts as 'Posted'
            "expectedDeliveryDate": _expectedDateController.text.trim(),
            "expectedDeliveryTime": _expectedTimeController.text.trim(),
            "expectedDateTime": expectedDateTime,
            "createdAt": FieldValue.serverTimestamp(),
            "createdBy": user.uid,
            "createdByName": createdByName,
            "paymentStatus": "Unpaid",
          });

      // Schedule the parcel to expire if not picked up by the expected time
      _scheduleParcelExpiry(parcelRef.id, expectedDateTime);

      if (mounted) {
        // Navigate to the Payment Page with the rounded price
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentPage(
              amount: price
                  .toDouble(), // Pass as double for the PaymentPage widget
              upiId: BUSINESS_UPI_ID,
              parcelId: parcelRef.id,
              otp: otp,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Haversine formula for distance calculation
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371.0; // Radius of Earth in kilometers
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; // Distance in km
  }

  double _toRadians(double degree) => degree * pi / 180;

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      // Format as DD/MM/YYYY
      _expectedDateController.text = "${date.day}/${date.month}/${date.year}";
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      // Format as HH:mm
      _expectedTimeController.text = "${time.hour}:${time.minute}";
    }
  }

  Future<void> _selectLocation(bool isPickup) async {
    final LatLng? selectedLocation = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerMap(
          initialLocation: isPickup ? _pickupLocation : _dropLocation,
        ),
      ),
    );

    if (selectedLocation != null) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          selectedLocation.latitude,
          selectedLocation.longitude,
        );
        if (placemarks.isNotEmpty) {
          Placemark placemark = placemarks.first;
          // Create a descriptive address string
          String address =
              "${placemark.name}, ${placemark.street}, ${placemark.locality}, ${placemark.administrativeArea}, ${placemark.country}";
          setState(() {
            if (isPickup) {
              _pickupLocation = selectedLocation;
              _pickupAddress = address;
              _pickupController.text = address;
            } else {
              _dropLocation = selectedLocation;
              _dropAddress = address;
              _dropController.text = address;
            }
            _updatePrice();
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error getting address: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Post Parcel", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E4ABF),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              /// Pickup
              TextFormField(
                controller: _pickupController,
                decoration: InputDecoration(
                  labelText: "Pickup Location",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.map),
                    onPressed: () => _selectLocation(true),
                  ),
                ),
                readOnly: true,
                validator: (v) =>
                    _pickupLocation == null ? "Select pickup location" : null,
              ),
              const SizedBox(height: 12),

              /// Drop
              TextFormField(
                controller: _dropController,
                decoration: InputDecoration(
                  labelText: "Drop Location",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.map),
                    onPressed: () => _selectLocation(false),
                  ),
                ),
                readOnly: true,
                validator: (v) =>
                    _dropLocation == null ? "Select drop location" : null,
              ),
              const SizedBox(height: 12),

              /// Weight
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: "Parcel Weight (kg)",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return "Enter weight";
                  final weight = int.tryParse(v);
                  if (weight == null || weight <= 0)
                    return "Weight must be positive integer";
                  if (weight > 10)
                    return "Weight over 10kg needs manual approval";
                  return null;
                },
              ),
              const SizedBox(height: 12),

              /// Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: "Description (Optional)",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),

              /// Expected Date & Time
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expectedDateController,
                      decoration: const InputDecoration(
                        labelText: "Expected Date",
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      onTap: _pickDate,
                      validator: (v) =>
                          v == null || v.isEmpty ? "Select date" : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _expectedTimeController,
                      decoration: const InputDecoration(
                        labelText: "Expected Time (HH:mm)",
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      onTap: _pickTime,
                      validator: (v) =>
                          v == null || v.isEmpty ? "Select time" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              /// Sender
              TextFormField(
                controller: _senderContactController,
                decoration: const InputDecoration(
                  labelText: "Sender Contact",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Enter mobile";
                  if (!RegExp(r"^\d{10}$").hasMatch(v))
                    return "Mobile number must be 10 digits";
                  return null;
                },
              ),
              const SizedBox(height: 12),

              /// Receiver
              TextFormField(
                controller: _receiverNameController,
                decoration: const InputDecoration(
                  labelText: "Receiver Name",
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Enter name";
                  if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(v))
                    return "Name should contain only letters";
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _receiverContactController,
                decoration: const InputDecoration(
                  labelText: "Receiver Contact",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Enter mobile";
                  if (!RegExp(r"^\d{10}$").hasMatch(v))
                    return "Mobile number must be 10 digits";
                  return null;
                },
              ),
              const SizedBox(height: 20),

              /// Parcel Image
              const Text("Parcel Photo (Optional):"),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    label: const Text(
                      "Choose Photo",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E4ABF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _parcelImage != null
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Text("No file selected"),
                ],
              ),
              const SizedBox(height: 20),

              /// Price
              Text(
                // **UPDATED: Display price as a rounded integer**
                "Estimated Price: ₹${price.toString()}",
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              /// Submit
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _createOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E4ABF),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text(
                        "Submit Parcel",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
