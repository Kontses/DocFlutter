import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // Επαναφορά import
import 'package:docflutter/feedback_screen.dart';
import 'package:docflutter/user_data_provider.dart'; // Import UserDataProvider
// import 'package:docflutter/theme_provider.dart'; // Δεν χρειάζεται πια εδώ
import 'package:flutter/services.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Δεν χρειάζεται πια εδώ

  // Αφαίρεση διαχείρισης state για τα δεδομένα χρήστη
  // Map<String, dynamic>? _userData;
  // bool _isLoading = true;
  // String? _errorMessage;

  // @override
  // void initState() {
  //   super.initState();
  //   _loadUserData();
  // }
  //
  // Future<void> _loadUserData() async {
  //   ...
  // }

  // Αποσύνδεση
  Future<void> _logout() async {
    await _auth.signOut();
    // Η πλοήγηση στην AuthScreen γίνεται αυτόματα από το StreamBuilder στο main.dart
    // Κλείνουμε αυτή την οθόνη για να μην μπορεί ο χρήστης να γυρίσει πίσω με back button
    if (mounted) {
        Navigator.of(context).pop(); // Κλείνει το ProfileScreen
    }
  }

  // Αποστολή email επαναφοράς κωδικού
  Future<void> _sendPasswordResetEmail() async {
    final user = _auth.currentUser;
    if (user?.email == null) {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not get user email.")),
          );
       }
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: user!.email!);
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
               content: Text("Password reset email sent to ${user.email}")),
         );
       }
    } on FirebaseAuthException catch (e) {
       print("Error sending password reset email: $e");
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("Failed to send reset email: ${e.message}")),
          );
       }
    } catch (e) {
       print("Unexpected error sending password reset email: $e");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("An unexpected error occurred.")),
         );
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Λήψη του UserDataProvider
    // listen: true για να ενημερώνεται αν αλλάξουν τα δεδομένα ενώ είναι ανοιχτή η οθόνη
    final userDataProvider = Provider.of<UserDataProvider>(context);

    // Αφαίρεση λήψης themeProvider
    // final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    // Προσδιορισμός κατάστασης φόρτωσης/σφάλματος από τον provider
    final bool isLoading = userDataProvider.isLoading;
    final UserData? userData = userDataProvider.userData;
    final String? errorMessage = userDataProvider.errorMessage;

    // --- Προσθήκη AnnotatedRegion ---
    final systemUiOverlayStyle = SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.black,
        systemNavigationBarIconBrightness: Theme.of(context).brightness == Brightness.light ? Brightness.dark : Brightness.light,
        // Η status bar θα οριστεί από το AppBar
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        appBar: AppBar(
          // --- Τροποποιήσεις AppBar ---
          systemOverlayStyle: SystemUiOverlayStyle(
             statusBarColor: Colors.transparent,
             statusBarIconBrightness: Theme.of(context).brightness == Brightness.light ? Brightness.dark : Brightness.light,
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          // backgroundColor: Theme.of(context).colorScheme.inversePrimary, // Αφαίρεση αυτού
          // foregroundColor: Theme.of(context).colorScheme.onPrimary, // Αφαίρεση foreground
          // --- Τέλος Τροποποιήσεων AppBar ---
          title: const Text('Profile & Settings'),
        ),
        body: isLoading // Έλεγχος φόρτωσης από τον provider
            ? const Center(child: CircularProgressIndicator())
             // Έλεγχος αν δεν φορτώνει, δεν υπάρχουν δεδομένα ΚΑΙ υπάρχει μήνυμα σφάλματος
            : !isLoading && userData == null && errorMessage != null
                ? Center(child: Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Text(errorMessage, textAlign: TextAlign.center),
                  ))
                : ListView( // Χρήση ListView για scrolling αν χρειαστεί
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      if (userData != null) ...[
                         ListTile(
                           leading: const Icon(Icons.person),
                           title: const Text('First Name'),
                           // Χρήση δεδομένων από το userData object
                           subtitle: Text(userData.firstName ?? 'Not set'),
                         ),
                         ListTile(
                           leading: const Icon(Icons.person_outline),
                           title: const Text('Last Name'),
                           subtitle: Text(userData.lastName ?? 'Not set'),
                         ),
                         ListTile(
                           leading: const Icon(Icons.email),
                           title: const Text('Email'),
                           subtitle: Text(userData.email ?? 'No email found'),
                         ),
                         const Divider(),
                      ],
                       // Εμφάνιση error ακόμα κι αν έχουμε κάποια παλιά δεδομένα
                       if (errorMessage != null && !isLoading)
                         Padding(
                           padding: const EdgeInsets.symmetric(vertical: 8.0),
                           child: Text(errorMessage, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                         ),

                      ListTile(
                        leading: const Icon(Icons.lock_reset),
                        title: const Text('Change Password'),
                        subtitle: const Text('Send password reset email'),
                        trailing: const Icon(Icons.send),
                        onTap: _sendPasswordResetEmail,
                      ),
                      const Divider(),

                      // Προσθήκη ListTile για Feedback πριν το Logout
                      ListTile(
                        leading: const Icon(Icons.feedback),
                        title: const Text('Send Feedback'),
                        subtitle: const Text('Report an issue or suggest a feature'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16), // Προαιρετικό εικονίδιο
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (ctx) => const FeedbackScreen()),
                          );
                        },
                      ),
                      const Divider(),

                      ListTile(
                        leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                        title: Text(
                          'Logout',
                           style: TextStyle(color: Theme.of(context).colorScheme.error)
                        ),
                        onTap: () async {
                           // Προαιρετικό: Εμφάνιση διαλόγου επιβεβαίωσης
                           final confirmLogout = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Confirm Logout'),
                                content: const Text('Are you sure you want to log out?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                     style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: const Text('Logout'),
                                  ),
                                ],
                              ),
                           );
                           if (confirmLogout == true) {
                             await _logout();
                           }
                        },
                      ),
                    ],
                  ),
      ), // --- Τέλος Scaffold ---
    ); // --- Τέλος AnnotatedRegion ---
  }
} 