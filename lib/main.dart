import 'package:docflutter/auth_screen.dart';
import 'package:docflutter/qr_scanner_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:docflutter/downloaded_manuals_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocFlutter',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Προαιρετικά: Εμφάνιση οθόνης φόρτωσης
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            // Ο χρήστης είναι συνδεδεμένος
            return const MyHomePage(title: 'DocFlutter Home');
          } else {
            // Ο χρήστης ΔΕΝ είναι συνδεδεμένος
            return const AuthScreen();
          }
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _scannedQrCode;

  void _openQrScanner(BuildContext context) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (ctx) => const QrScannerScreen()),
    );

    if (result != null && mounted) {
      setState(() {
        _scannedQrCode = result;
      });
    }
  }

  // Συνάρτηση για πλοήγηση στα κατεβασμένα αρχεία
  void _openDownloadedManuals(BuildContext context) {
     Navigator.of(context).push(
        MaterialPageRoute(builder: (ctx) => const DownloadedManualsScreen()),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Welcome! Press the button to scan a QR code.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _openQrScanner(context),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code'),
            ),
            const SizedBox(height: 10), // Μικρότερο κενό
            // Προσθήκη κουμπιού για τα κατεβασμένα αρχεία
            ElevatedButton.icon(
              onPressed: () => _openDownloadedManuals(context),
              icon: const Icon(Icons.folder_open),
              label: const Text('View Downloads'),
              style: ElevatedButton.styleFrom(
                 backgroundColor: Colors.grey[300], // Διαφορετικό χρώμα (προαιρετικά)
                 foregroundColor: Colors.black87
              ),
            ),
            const SizedBox(height: 20),
            if (_scannedQrCode != null)
              Text('Last scanned code: $_scannedQrCode'),
          ],
        ),
      ),
    );
  }
}
