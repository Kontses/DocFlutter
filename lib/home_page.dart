import 'package:docflutter/downloaded_manuals_screen.dart';
import 'package:docflutter/qr_scanner_screen.dart';
import 'package:docflutter/theme_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  void _scanQrCode(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => const QrScannerScreen()),
    );
  }

  void _logout(BuildContext context) {
    FirebaseAuth.instance.signOut();
  }

  void _openDownloadedManuals(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => const DownloadedManualsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('DocFlutter Home'),
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
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
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
                'Welcome!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (user?.email != null)
                 Padding(
                   padding: const EdgeInsets.only(top: 8.0, bottom: 20.0),
                   child: Text(user!.email!, style: Theme.of(context).textTheme.bodySmall),
                 ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _scanQrCode(context),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR Code'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
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