import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _travelAreaController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _upiController = TextEditingController();

  String? _idType;
  File? _idImage;
  bool _isLoading = false;
  bool _acceptTerms = false;

  final ImagePicker picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          _idImage = File(picked.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Image pick error: $e")));
    }
  }

  Future<void> _selectDOB(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() {
        _dobController.text =
            "${pickedDate.day}-${pickedDate.month}-${pickedDate.year}";
      });
    }
  }

  void _showTermsFullScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text("Terms & Conditions"),
            backgroundColor: const Color(0xFF1E4ABF),
          ),
          body: const Padding(
            padding: EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Text(
                "1. Users must provide accurate personal details and valid ID.\n"
                "2. All parcels are at sender's responsibility until accepted by a traveler.\n"
                "3. Admin verification is required before accessing app features.\n"
                "4. Payments must be processed only through the app’s UPI system.\n"
                "5. Misuse of the app may result in account suspension or termination.\n"
                "6. Travelers must ensure safe handling and timely delivery of parcels.\n"
                "7. Senders must declare parcel contents truthfully; illegal items are prohibited.\n"
                "8. OTP confirmation is mandatory for successful parcel delivery.\n"
                "9. Travelers receive payment only after verified parcel delivery.\n"
                "10. TravelDrop is not liable for delays caused by traffic, weather, or emergencies.\n"
                "11. Users must not share OTPs or sensitive data with unauthorized persons.\n"
                "12. Any disputes will be handled according to TravelDrop’s company policy.\n"
                "13. Reports of misconduct or parcel issues must be submitted through the app.\n"
                "14. Fraudulent activity or false information may lead to legal action.\n"
                "15. By registering, users agree to all Terms & Conditions and future updates.\n",

                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Accept Terms & Conditions first")),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_idImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload your ID document")),
      );
      return;
    }

    setState(() => _isLoading = true);

    UserCredential? userCredential;
    String? idImageUrl;
    Reference? fileRef;

    try {
      userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final uid = userCredential.user!.uid;

      try {
        final fileName =
            '${_idType?.replaceAll(' ', '_') ?? 'id_doc'}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storagePath = 'kyc_docs/$uid/$fileName';

        fileRef = FirebaseStorage.instance.ref().child(storagePath);

        await fileRef.putFile(
          _idImage!,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        idImageUrl = await fileRef.getDownloadURL();
      } on FirebaseException catch (e) {
        await userCredential!.user?.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "ID Upload failed: ${e.code}. Registration cancelled.",
            ),
          ),
        );
        return;
      }

      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          "name": _nameController.text.trim(),
          "email": _emailController.text.trim(),
          "phone": _phoneController.text.trim(),
          "dob": _dobController.text.trim(),
          "address": _addressController.text.trim(),
          "travelArea": _travelAreaController.text.trim().isEmpty
              ? null
              : _travelAreaController.text.trim(),
          "idType": _idType,
          "idNumber": _idNumberController.text.trim(),
          "idImageUrl": idImageUrl,
          "upiId": _upiController.text.trim(),
          "kycStatus": "Pending",
          "role": "user",
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        });
      } on FirebaseException catch (e) {
        await fileRef?.delete();
        await userCredential.user?.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Database Error: ${e.message}. Registration cancelled.",
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registration Successful!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = e.message ?? "Registration failed.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Auth Error: $errorMessage"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Registration failed: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _travelAreaController.dispose();
    _idNumberController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E4ABF),
        title: const Text("Register", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Full Name",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? "Enter your name" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Enter your email";
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(v))
                      return "Enter a valid email address";
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v!.length < 6 ? "Minimum 6 characters required" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "Phone",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty)
                      return "Enter your phone number";
                    if (!RegExp(r'^[0-9]{10}$').hasMatch(v))
                      return "Enter a valid 10-digit phone number";
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dobController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "Date of Birth",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () => _selectDOB(context),
                  validator: (v) =>
                      v!.isEmpty ? "Select your Date of Birth" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Address",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? "Enter your address" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _travelAreaController,
                  decoration: const InputDecoration(
                    labelText: "Travel Area (Optional)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _idType,
                  items: ["PAN", "Aadhaar", "Driving License"]
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _idType = v),
                  decoration: const InputDecoration(
                    labelText: "ID Type",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null ? "Select an ID type" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _idNumberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "ID Number",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Enter your ID number";
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _upiController,
                  decoration: const InputDecoration(
                    labelText: "UPI ID",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Enter your UPI ID";
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "ID Document Upload *",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Upload a clear image of your ID document",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: _pickImage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E4ABF),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                              ),
                              child: const Text(
                                "Select ID",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _idImage != null
                                  ? const Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "Document Selected",
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      "No file selected",
                                      style: TextStyle(color: Colors.grey),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Terms & Conditions -- fixed with RichText so it wraps!
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                              text: "I accept the ",
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 15,
                              ),
                            ),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: _showTermsFullScreen,
                                child: const Text(
                                  "Terms & Conditions",
                                  style: TextStyle(
                                    color: Color(0xFF1E4ABF),
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      value: _acceptTerms,
                      onChanged: (v) =>
                          setState(() => _acceptTerms = v ?? false),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text("Creating your account..."),
                          ],
                        ),
                      )
                    : SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E4ABF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Register",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
