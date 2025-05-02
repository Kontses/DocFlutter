import 'dart:io';
import 'package:docflutter/pdf_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p; // Για τον χειρισμό path

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

          return ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: Text(fileName),
            onTap: () => _openPdf(file.path, fileName),
            trailing: IconButton(
               icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
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
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Downloaded Manuals'),
        actions: [
          // Κουμπί ανανέωσης
          IconButton(
             icon: const Icon(Icons.refresh),
             tooltip: 'Refresh List',
             onPressed: _isLoading ? null : _loadDownloadedPdfs, // Απενεργοποίηση κατά τη φόρτωση
          ),
        ],
      ),
      body: content,
    );
  }
} 