import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:docflutter/user_data_provider.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _screenshotFile; // Αρχείο εικόνας που επιλέχθηκε

  bool _isSubmitting = false;

  Future<void> _pickScreenshot() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _screenshotFile = image;
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick image.')),
        );
      }
    }
  }

  Future<String?> _uploadScreenshot(XFile imageFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null; // Χρειάζεται χρήστης για το path

    try {
      // Δημιουργία ονόματος αρχείου μόνο με το timestamp
      final timestamp = DateTime.now().toIso8601String();
      final fileName = '$timestamp.jpg'; 
      // Δημιουργία σωστής διαδρομής: feedback_screenshots/userId/fileName
      final ref = FirebaseStorage.instance
          .ref()
          .child('feedback_screenshots') // Φάκελος βάσης
          .child(user.uid)             // Υποφάκελος με το User ID
          .child(fileName);            // Όνομα αρχείου

      final uploadTask = await ref.putFile(File(imageFile.path));
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Error uploading screenshot: $e");
      return null;
    }
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You must be logged in to send feedback.')),
          );
       }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    String? screenshotUrl;
    if (_screenshotFile != null) {
      screenshotUrl = await _uploadScreenshot(_screenshotFile!);
      if (screenshotUrl == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload screenshot. Submitting without it.')),
        );
      }
    }

    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'userId': user.uid,
        'email': user.email, // Προσθήκη email για ευκολία
        'subject': _subjectController.text.trim(),
        'description': _descriptionController.text.trim(),
        'screenshotUrl': screenshotUrl, // Μπορεί να είναι null
        'timestamp': Timestamp.now(),
        'status': 'new', // Προαιρετικό: αρχική κατάσταση
      });

       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feedback submitted successfully!')),
          );
          Navigator.of(context).pop(); // Επιστροφή στην προηγούμενη οθόνη
       }
    } catch (e) {
       print("Error submitting feedback: $e");
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to submit feedback. Please try again.')),
          );
       }
    } finally {
       if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
       }
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Λήψη του UserDataProvider για το όνομα
    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    // Ανάκτηση ονόματος (με έλεγχο για null/empty)
    final firstName = userDataProvider.userData?.firstName;
    final greetingName = (firstName != null && firstName.trim().isNotEmpty) ? firstName : 'there';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Send Feedback'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView( // ListView για αποφυγή overflow
            children: [
              // --- Προσθήκη Μηνύματος Καλωσορίσματος ---
              Text(
                'Hi $greetingName!',
                style: Theme.of(context).textTheme.titleLarge, // Μεγαλύτερο μέγεθος
              ),
              const SizedBox(height: 4), // Μικρό κενό
              Text(
                'Ask us anything, or share your feedback.',
                 style: Theme.of(context).textTheme.bodySmall, // Επαναφορά στο αρχικό στυλ
              ),
              const SizedBox(height: 20), // Μεγαλύτερο κενό πριν το Subject
              // --- Τέλος Μηνύματος Καλωσορίσματος ---

              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'e.g., Bug report, Feature request',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a subject.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Please describe the issue or suggestion...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                 children: [
                   ElevatedButton.icon(
                     onPressed: _pickScreenshot,
                     icon: const Icon(Icons.attach_file),
                     label: const Text('Attach Screenshot'),
                   ),
                   const SizedBox(width: 10),
                    // Εμφάνιση προεπισκόπησης ή ονόματος αρχείου
                   if (_screenshotFile != null)
                     Expanded(
                       child: Text(
                         _screenshotFile!.name, 
                         overflow: TextOverflow.ellipsis,
                         style: Theme.of(context).textTheme.bodySmall
                       ),
                     ),
                 ],
              ),
               // Προαιρετική προεπισκόπηση εικόνας
              if (_screenshotFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Image.file(
                    File(_screenshotFile!.path),
                    height: 150,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft, // Στοίχιση αριστερά
                  ),
                ),
              const SizedBox(height: 24),
              if (_isSubmitting)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                     padding: const EdgeInsets.symmetric(vertical: 12),
                     textStyle: const TextStyle(fontSize: 16)
                  ),
                  onPressed: _submitFeedback,
                  child: const Text('Submit Feedback'),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 