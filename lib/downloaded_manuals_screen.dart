import 'dart:io';
import 'dart:math'; // Προσθήκη για το pow
import 'package:docflutter/pdf_viewer_screen.dart';
import 'package:docflutter/download_history_screen.dart'; // Import της νέας οθόνης
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p; // Για τον χειρισμό path
import 'package:flutter/services.dart';

class DownloadedManualsScreen extends StatefulWidget {
  const DownloadedManualsScreen({super.key});

  @override
  State<DownloadedManualsScreen> createState() => _DownloadedManualsScreenState();
}

class _DownloadedManualsScreenState extends State<DownloadedManualsScreen> {
  List<FileSystemEntity> _pdfFiles = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDownloadedPdfs();
  }

  Future<void> _loadDownloadedPdfs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final manualsDir = Directory('${docDir.path}/downloaded_manuals');

      if (await manualsDir.exists()) {
        // Λήψη όλων των entities (αρχεία & φάκελοι) και φιλτράρισμα για PDF αρχεία
        final files = manualsDir.listSync()
                          .where((item) => item is File && p.extension(item.path).toLowerCase() == '.pdf')
                          .toList();
        setState(() {
          _pdfFiles = files;
          _isLoading = false;
        });
      } else {
        // Ο φάκελος δεν υπάρχει (δεν έχουν κατέβει αρχεία ακόμα)
        setState(() {
          _pdfFiles = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error loading downloaded files: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  // Βοηθητική συνάρτηση για μορφοποίηση μεγέθους αρχείου
  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  void _openPdf(String filePath, String fileName) {
     Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => PdfViewerScreen(
            pdfPath: filePath,
            pdfName: fileName,
          ),
        ),
      );
  }

  Future<void> _deletePdf(File fileToDelete) async {
    try {
      await fileToDelete.delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${p.basename(fileToDelete.path)} deleted.')),
      );
      _loadDownloadedPdfs(); // Ανανέωση της λίστας
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting file: ${e.toString()}')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    Widget content = const Center(child: Text('No downloaded manuals found.'));

    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error: $_errorMessage', textAlign: TextAlign.center),
        ),
      );
    } else if (_pdfFiles.isNotEmpty) {
      content = ListView.builder(
        itemCount: _pdfFiles.length,
        itemBuilder: (ctx, index) {
          final file = _pdfFiles[index] as File; // Ξέρουμε ότι είναι File από το φιλτράρισμα
          final fileName = p.basename(file.path); // Πάρε μόνο το όνομα αρχείου
          final fileSize = file.statSync().size; // Λήψη μεγέθους αρχείου
          final formattedSize = _formatBytes(fileSize, 1); // Μορφοποίηση μεγέθους

          return ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: Text(fileName),
            onTap: () => _openPdf(file.path, fileName),
            trailing: Row( // Χρήση Row για να χωρέσουν το μέγεθος και το κουμπί
              mainAxisSize: MainAxisSize.min, // Για να πιάνει τον ελάχιστο χώρο
              children: [
                Text(
                  formattedSize,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey, // Προαιρετικά, για διακριτικό χρώμα
                  ),
                ),
                const SizedBox(width: 8), // Κενό μεταξύ μεγέθους και κουμπιού
                IconButton(
                  icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                  tooltip: 'Delete $fileName', // Προσθήκη tooltip
                  onPressed: () async {
                    // Εμφάνιση διαλόγου επιβεβαίωσης πριν τη διαγραφή
                    final confirm = await showDialog<bool>(
                       context: context,
                       builder: (ctx) => AlertDialog(
                          title: const Text('Confirm Deletion'),
                          content: Text('Are you sure you want to delete $fileName?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Delete'),
                            ),
                          ],
                       ),
                    );
                    if (confirm == true) {
                       _deletePdf(file);
                    }
                  },
                ),
              ],
            ),
          );
        },
      );
    }

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
          // --- Τέλος Τροποποιήσεων AppBar ---
          title: const Text('Downloaded Manuals'),
          actions: [
            // Κουμπί Ιστορικού
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'View Download History',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => const DownloadHistoryScreen()),
                );
              },
            ),
            // Κουμπί ανανέωσης
            IconButton(
               icon: const Icon(Icons.refresh),
               tooltip: 'Refresh List',
               onPressed: _isLoading ? null : _loadDownloadedPdfs, // Απενεργοποίηση κατά τη φόρτωση
            ),
          ],
        ),
        body: content,
      ), // --- Τέλος Scaffold ---
    ); // --- Τέλος AnnotatedRegion ---
  }
} 