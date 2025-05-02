import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isLogin = true; // Toggle between Login and Register
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submitAuthForm() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final auth = FirebaseAuth.instance;
      UserCredential userCredential;

      if (_isLogin) {
        // Log in user
        userCredential = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        // Navigation to home screen will happen based on auth state changes
      } else {
        // Register user
        final firstName = _firstNameController.text.trim();
        final lastName = _lastNameController.text.trim();
        userCredential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        // Αποθήκευση επιπλέον δεδομένων στο Firestore
        await _saveUserData(userCredential.user, firstName, lastName);
      }
    } on FirebaseAuthException catch (error) {
      _errorMessage = error.message ?? 'Authentication failed.';
    } catch (error) {
      _errorMessage = 'An unexpected error occurred.';
      // print(error); // For debugging
    } finally {
      if (mounted) { // Check if the widget is still in the tree
         setState(() {
           _isLoading = false;
         });
      }
    }
  }

  Future<void> _saveUserData(User? user, String firstName, String lastName) async {
    if (user == null) {
      // Δεν θα έπρεπε να συμβεί αν η εγγραφή ήταν επιτυχής, αλλά για ασφάλεια
      print("User is null, cannot save data.");
      _errorMessage = "Could not save user data. Please try again.";
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'email': user.email, // Αποθήκευση και του email για ευκολία
        // Μπορείτε να προσθέσετε κι άλλα πεδία εδώ, π.χ., createdAt
        'createdAt': Timestamp.now(),
      });
      print("User data saved to Firestore for UID: ${user.uid}");
    } catch (e) {
      print("Error saving user data to Firestore: $e");
      // Εμφάνιση μηνύματος λάθους στον χρήστη
      _errorMessage = "Failed to save user details. Please try logging in.";
      // Εδώ θα μπορούσαμε να κάνουμε rollback της εγγραφής αν ήταν κρίσιμο
      // await user.delete(); // Προσοχή: διαγράφει τον χρήστη από το Auth
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: <Widget>[
              const Spacer(),
              Image.asset(
                Theme.of(context).brightness == Brightness.dark
                    ? 'assets/icons/logo_login_white.png'
                    : 'assets/icons/logo_login_blue.png',
                height: 100,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.business,
                    size: 100,
                    color: Theme.of(context).iconTheme.color,
                  );
                },
              ),
              const SizedBox(height: 10), 
              Text(
                'Metro Μanuals',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 30),
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (!_isLogin) ...[
                      TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(labelText: 'First Name'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your first name.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(labelText: 'Last Name'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your last name.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty || !value.contains('@')) {
                          return 'Please enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.trim().length < 6) {
                          return 'Password must be at least 6 characters long.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                        ),
                        onPressed: _submitAuthForm,
                        child: Text(_isLogin ? 'Login' : 'Register'),
                      ),
                    if (!_isLoading)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            _errorMessage = null;
                            if(_isLogin) {
                              _firstNameController.clear();
                              _lastNameController.clear();
                            }
                            _formKey.currentState?.reset();
                          });
                        },
                        child: Text(_isLogin
                            ? 'Create new account'
                            : 'I already have an account'),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'powered by TRAXIS Engineering',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
} 