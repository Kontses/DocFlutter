import 'dart:io'; // Προσθήκη import
import 'package:docflutter/pdf_viewer_screen.dart'; // Προσθήκη import
import 'package:firebase_auth/firebase_auth.dart'; // Προσθήκη import
import 'package:firebase_storage/firebase_storage.dart'; // Προσθήκη import
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart'; // Προσθήκη import
import 'package:http/http.dart' as http; // Προσθήκη import
import 'package:flutter/services.dart'; // Για PlatformException
import 'package:image_picker/image_picker.dart'; // Εισαγωγή image_picker

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isLoading = false;
  String? _loadingMessage;
  // ImagePicker instance
  final ImagePicker _picker = ImagePicker();

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
  Future<void> _downloadAndShowPdf(String rawCode) async {
    if (_isLoading) return;

    print('--- QR Code Scanned ---');
    print('Raw code from scanner: "$rawCode"');

    // --- Ανάλυση του κώδικα QR --- 
    String pdfFileName = rawCode;
    int initialPage = 0; // Προεπιλογή σε 0 (πρώτη σελίδα)
    const String pageSeparator = '#page=';

    if (rawCode.contains(pageSeparator)) {
      final parts = rawCode.split(pageSeparator);
      if (parts.length == 2) {
        pdfFileName = parts[0]; // Το όνομα αρχείου είναι το πρώτο μέρος
        final pageString = parts[1];
        final parsedPage = int.tryParse(pageString);
        if (parsedPage != null && parsedPage > 0) { // Η σελίδα πρέπει να είναι > 0
          initialPage = parsedPage - 1; // Μετατροπή σε 0-indexed
          print('Extracted filename: "$pdfFileName", initial page (0-indexed): $initialPage');
        } else {
          print('Invalid page number found: "$pageString". Defaulting to page 0.');
           pdfFileName = rawCode; // Αν το page number δεν είναι σωστό, πάρε όλο το string ως filename
           initialPage = 0;
        }
      } else {
         print('Invalid format after separator. Treating whole code as filename.');
         pdfFileName = rawCode; // Αν η μορφή είναι λάθος μετά το #, πάρε όλο το string ως filename
         initialPage = 0;
      }
    } else {
        print('No page separator found. Treating whole code as filename.');
    }
    // --- Τέλος Ανάλυσης --- 


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
      final storagePath = 'manuals/$pdfFileName';
      print('Attempting to access Storage Path: "$storagePath"');
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
        final localFilePath = '${manualsDir.path}/$pdfFileName';
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
                pdfName: pdfFileName, // Χρήση του αναλυμένου ονόματος
                initialPage: initialPage, // Πέρασμα της αρχικής σελίδας
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

  // Νέα συνάρτηση για σάρωση από γκαλερί
  Future<void> _scanImageFromGallery() async {
    if (_isLoading) return; // Αποφυγή εκτέλεσης αν ήδη φορτώνει

    try {
      // 1. Επιλογή εικόνας
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        print('No image selected.');
        return; // Ο χρήστης ακύρωσε την επιλογή
      }

      print('Image selected: ${image.path}');

      setState(() {
        _isLoading = true;
        _loadingMessage = 'Analyzing image...';
      });

      // 2. Ανάλυση εικόνας για QR code
      final BarcodeCapture? result = await cameraController.analyzeImage(image.path);

      // 3. Έλεγχος αποτελέσματος
      if (result != null && result.barcodes.isNotEmpty) {
        final String? code = result.barcodes.first.rawValue;
        if (code != null && code.isNotEmpty) {
          print('QR Code found in image: $code');
          // Κλήση της υπάρχουσας συνάρτησης για λήψη/προβολή
          // Πρέπει να γίνει εκτός του setState
          await _downloadAndShowPdf(code);
        } else {
           print('Found barcode but rawValue is null or empty.');
           if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR code data is empty.')),
              );
           }
        }
      } else {
        print('No QR code found in the selected image.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No QR code found in the image.')),
          );
        }
      }
    } on PlatformException catch (e) {
       print('Failed to pick or analyze image: ${e.message}');
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error accessing gallery or analyzing image: ${e.message}')),
          );
       }
    } catch (e) {
      print('An unexpected error occurred: $e');
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
          );
       }
    } finally {
      // Επαναφορά κατάστασης φόρτωσης ΜΟΝΟ αν δεν καλέστηκε το _downloadAndShowPdf
      // (το οποίο κάνει το δικό του reset στο τέλος ή σε σφάλμα)
      // Πρακτικά, αν δεν βρέθηκε QR code ή υπήρξε σφάλμα *πριν* την κλήση download
      if (mounted && _isLoading && _loadingMessage == 'Analyzing image...') {
         setState(() {
           _isLoading = false;
           _loadingMessage = null;
         });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          // Κουμπί για επιλογή από γκαλερί
          IconButton(
            icon: const Icon(Icons.image),
            tooltip: 'Scan from Gallery',
            onPressed: _scanImageFromGallery,
          ),
          // Κουμπί φακού
          IconButton(
            icon: const Icon(Icons.flash_on),
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