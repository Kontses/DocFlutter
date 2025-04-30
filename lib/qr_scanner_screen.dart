import 'dart:io'; // Προσθήκη import
import 'package:docflutter/pdf_viewer_screen.dart'; // Προσθήκη import
import 'package:firebase_auth/firebase_auth.dart'; // Προσθήκη import
import 'package:firebase_storage/firebase_storage.dart'; // Προσθήκη import
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart'; // Προσθήκη import
import 'package:http/http.dart' as http; // Προσθήκη import

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isLoading = false;
  String? _loadingMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  // Συνάρτηση για λήψη και προβολή PDF
  Future<void> _downloadAndShowPdf(String code) async {
    // ΠΡΟΣΘΗΚΗ PRINT ΓΙΑ DEBUG:
    print('--- QR Code Scanned ---');
    print('Raw code from scanner: "$code"');
    // Το code πρέπει να είναι "ATS_demo.pdf"

    if (_isLoading) return; // Αποφυγή διπλής εκτέλεσης

    // Έλεγχος αν ο χρήστης είναι συνδεδεμένος
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to download manuals.')),
      );
      // Σταμάτημα της διαδικασίας αν ο χρήστης δεν είναι συνδεδεμένος
      // Προαιρετικά: πλοήγηση πίσω στην οθόνη login
      // Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Fetching file info...';
    });

    try {
      // 1. Κατασκευή path στο Firebase Storage
      // Σημαντικό: Το όνομα αρχείου στο Storage ΠΡΕΠΕΙ να ταιριάζει με το 'code' από το QR
      final storagePath = 'manuals/$code'; // Υποθέτουμε φάκελο 'manuals'

      // ΠΡΟΣΘΗΚΗ PRINT ΓΙΑ DEBUG:
      print('Attempting to access Storage Path: "$storagePath"');
      // --- ΤΕΛΟΣ PRINT ---

      final storageRef = FirebaseStorage.instance.ref().child(storagePath);

      // 2. Λήψη του Download URL
      final downloadUrl = await storageRef.getDownloadURL();

      setState(() {
        _loadingMessage = 'Downloading file...';
      });

      // 3. Λήψη του αρχείου με HTTP
      final response = await http.get(Uri.parse(downloadUrl));

      if (response.statusCode == 200) {
        // 4. Εύρεση προσωρινού καταλόγου
        final docDir = await getApplicationDocumentsDirectory();
        final manualsDir = Directory('${docDir.path}/downloaded_manuals');
        // Δημιουργία του καταλόγου αν δεν υπάρχει
        if (!await manualsDir.exists()) {
          await manualsDir.create(recursive: true);
          print('Created directory: ${manualsDir.path}');
        }

        // Χρήση του νέου καταλόγου
        final localFilePath = '${manualsDir.path}/$code';
        final localFile = File(localFilePath);
        print('Saving PDF to: $localFilePath');

        // 6. Εγγραφή των δεδομένων στο τοπικό αρχείο
        await localFile.writeAsBytes(response.bodyBytes);

        setState(() {
          _loadingMessage = 'Opening file...';
        });

        // 7. Πλοήγηση στον PDF Viewer
        if (mounted) { // Έλεγχος αν το widget υπάρχει ακόμα
          // Χρήση pushReplacement αντί για push αν δεν θέλουμε να γυρίσει πίσω στον scanner
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => PdfViewerScreen(
                pdfPath: localFilePath,
                pdfName: code, // Χρήση του ονόματος από το QR ως τίτλο
              ),
            ),
          );
          // Μετά την επιστροφή από τον PDF viewer, ξανα-ενεργοποιούμε το scanner
          if (mounted) {
             setState(() {
               _isLoading = false;
               _loadingMessage = null;
             });
          }
        }

      } else {
        throw Exception('Failed to download file: Status code ${response.statusCode}');
      }
    } on FirebaseException catch (e) {
      // print('Storage Error: ${e.code} - ${e.message}');
      String userMessage = 'Error fetching file.';
      if (e.code == 'object-not-found') {
        userMessage = 'Manual not found for this QR code.';
      } else if (e.code == 'unauthorized') {
        userMessage = 'You do not have permission to access this file.';
      }
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(userMessage)),
         );
         setState(() {
           _isLoading = false;
           _loadingMessage = null;
         });
      }
    } catch (e) {
      // print('Generic Error: $e');
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An error occurred: ${e.toString()}')),
          );
          setState(() {
            _isLoading = false;
            _loadingMessage = null;
          });
       }
    }
    // Το finally δεν χρειάζεται εδώ, το state αλλάζει στα catch ή μετά την πλοήγηση
  }

  void _handleBarcode(BarcodeCapture capture) {
    // Δεν καλούμε setState εδώ αμέσως, η _downloadAndShowPdf θα το κάνει
    // if (_isLoading) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null && code.isNotEmpty && !_isLoading) {
         // print('QR Code Found: $code');
         // Καλούμε τη νέα συνάρτηση για λήψη και προβολή
         _downloadAndShowPdf(code);
      }
    }
    // Δεν χρειάζεται να κάνουμε reset το _isLoading εδώ
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          // Απλοποίηση κουμπιού φακού
          IconButton(
            icon: const Icon(Icons.flash_on), // Σταθερό εικονίδιο
            tooltip: 'Toggle Torch',
            onPressed: () => cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center, // Στοίχιση στο κέντρο
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _handleBarcode,
          ),
          // Overlay στόχευσης
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(
                  color: _isLoading ? Colors.grey : Colors.green, // Αλλαγή χρώματος όταν φορτώνει
                  width: 4),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          // Ένδειξη φόρτωσης στο κέντρο
          if (_isLoading)
            Container(
               // Ημιδιαφανές μαύρο φόντο
               color: Colors.black.withOpacity(0.6),
               child: Center(
                 child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      if (_loadingMessage != null)
                         Text(
                           _loadingMessage!,
                           style: const TextStyle(color: Colors.white, fontSize: 16),
                           textAlign: TextAlign.center,
                         ),
                    ],
                 ),
               ),
            ),
        ],
      ),
    );
  }
} 