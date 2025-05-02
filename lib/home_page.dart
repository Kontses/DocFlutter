import 'package:docflutter/downloaded_manuals_screen.dart';
import 'package:docflutter/qr_scanner_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docflutter/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:docflutter/theme_provider.dart';
import 'package:docflutter/user_data_provider.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  void _scanQrCode(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => const QrScannerScreen()),
    );
  }

  void _openDownloadedManuals(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => const DownloadedManualsScreen()),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userDataProvider = Provider.of<UserDataProvider>(context);

    String welcomeMessage;
    if (userDataProvider.isLoading) {
      welcomeMessage = 'Loading user...';
    } else if (userDataProvider.userData != null) {
      final firstName = userDataProvider.userData!.firstName;
      if (firstName != null && firstName.trim().isNotEmpty) {
        welcomeMessage = 'Welcome, $firstName!';
      } else {
        welcomeMessage = 'Welcome, ${userDataProvider.userData!.displayName}!';
      }
    } else {
      welcomeMessage = 'Welcome!';
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Metro Μanuals'),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Profile & Settings',
            onPressed: () => _openProfile(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                welcomeMessage,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)),
                onPressed: () => _scanQrCode(context),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR Code'),
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                 style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)),
                onPressed: () => _openDownloadedManuals(context),
                icon: const Icon(Icons.folder_open),
                label: const Text('View Downloads'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 