import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

class UserData {
  final String uid;
  final String? firstName;
  final String? lastName;
  final String? email;
  // Μπορούμε να προσθέσουμε κι άλλα πεδία αν χρειαστεί

  UserData({
    required this.uid,
    this.firstName,
    this.lastName,
    this.email,
  });

  String get displayName {
    final name = "${firstName ?? ''} ${lastName ?? ''}".trim();
    return name.isNotEmpty ? name : email ?? 'User'; // Fallback στο email ή 'User'
  }
}

class UserDataProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserData? _userData;
  bool _isLoading = false;
  String? _errorMessage;

  UserData? get userData => _userData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadUserData(User? user) async {
    if (user == null) {
      // Χρήστης αποσυνδέθηκε, καθαρισμός δεδομένων
      _userData = null;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    // Αν τα δεδομένα είναι ήδη φορτωμένα για τον ίδιο χρήστη, δεν κάνουμε τίποτα
    if (_userData != null && _userData!.uid == user.uid) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    // Ειδοποιούμε ότι ξεκίνησε η φόρτωση
    // Χρησιμοποιούμε addPostFrameCallback για να μην καλέσουμε notifyListeners κατά τη διάρκεια ενός build
    WidgetsBinding.instance.addPostFrameCallback((_) {
        if(_isLoading) { // Ελέγχουμε ξανά μήπως άλλαξε γρήγορα η κατάσταση
             notifyListeners();
        }
    });

    try {
      final docSnapshot =
          await _firestore.collection('users').doc(user.uid).get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        _userData = UserData(
          uid: user.uid,
          firstName: data?['firstName'] as String?,
          lastName: data?['lastName'] as String?,
          email: data?['email'] as String? ?? user.email, // Προτιμάμε το email από Firestore, αλλιώς από Auth
        );
        _errorMessage = null;
      } else {
        // Δεν βρέθηκε έγγραφο στο Firestore, χρησιμοποιούμε μόνο τα βασικά από το Auth
        _userData = UserData(
          uid: user.uid,
          email: user.email,
        );
        _errorMessage = "User profile data not found in database."; // Ήπιο μήνυμα
      }
    } catch (e) {
      print("Error loading user data in Provider: $e");
      _errorMessage = "Failed to load user data.";
      _userData = UserData(uid: user.uid, email: user.email); // Fallback στα βασικά
       // Εδώ θα μπορούσαμε να κρατήσουμε τα παλιά δεδομένα αν αποτύχει η φόρτωση
       // αλλά ο χρήστης παραμένει ο ίδιος, αλλά για τώρα τα καθαρίζουμε
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

   // Συνάρτηση για καθαρισμό δεδομένων κατά την αποσύνδεση (εναλλακτική του loadUserData(null))
  void clearUserData() {
     _userData = null;
     _isLoading = false;
     _errorMessage = null;
     notifyListeners();
  }
} 