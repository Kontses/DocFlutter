import 'dart:convert';
import 'dart:io';

import 'package:docflutter/pdf_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Για μορφοποίηση ημερομηνίας
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class DownloadHistoryScreen extends StatefulWidget {
  const DownloadHistoryScreen({super.key});

  @override
  State<DownloadHistoryScreen> createState() => _DownloadHistoryScreenState();
}

class _DownloadHistoryScreenState extends State<DownloadHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      const historyKey = 'download_history';
      final historyJson = prefs.getStringList(historyKey) ?? [];
      final historyList = historyJson
          .map((item) => jsonDecode(item) as Map<String, dynamic>)
          .toList();

      setState(() {
        _history = historyList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error loading history: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  Future<void> _openPdfFromHistory(Map<String, dynamic> historyEntry) async {
    final String filePath = historyEntry['filePath'] ?? '';
    final String fileName = historyEntry['fileName'] ?? 'Unknown File';
    final int pageIndex = historyEntry['page'] ?? 0;

    if (filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: File path is missing in history entry.')),
      );
      return;
    }

    final file = File(filePath);
    if (await file.exists()) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => PdfViewerScreen(
            pdfPath: filePath,
            pdfName: fileName,
            initialPage: pageIndex, // Περνάμε την αποθηκευμένη σελίδα
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File "$fileName" no longer exists on device.')),
      );
      // Προαιρετικά: Ρώτημα για αφαίρεση της εγγραφής από το ιστορικό;
    }
  }

  // Συνάρτηση για διαγραφή μιας εγγραφής ιστορικού
  Future<void> _deleteHistoryEntry(int index) async {
     try {
      final prefs = await SharedPreferences.getInstance();
      const historyKey = 'download_history';
      // Δεν χρειάζεται να ξαναδιαβάσουμε όλο το JSON, απλά αφαιρούμε από το state
      final entryToRemove = _history[index];
      final List<Map<String, dynamic>> currentHistory = List.from(_history);
      currentHistory.removeAt(index);

      // Ενημέρωση του SharedPreferences
      final updatedHistoryJson = currentHistory
          .map((item) => jsonEncode(item))
          .toList();
      await prefs.setStringList(historyKey, updatedHistoryJson);

      // Ενημέρωση του UI
      setState(() {
        _history = currentHistory;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed "${entryToRemove['fileName']}" from history.')),
      );

     } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing history entry: ${e.toString()}')),
        );
     }
  }

 // Συνάρτηση για διαγραφή όλου του ιστορικού
  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
           title: const Text('Clear History'),
           content: const Text('Are you sure you want to delete all download history entries?'),
           actions: [
             TextButton(
               onPressed: () => Navigator.of(ctx).pop(false),
               child: const Text('Cancel'),
             ),
             TextButton(
               onPressed: () => Navigator.of(ctx).pop(true),
               child: const Text('Clear All', style: TextStyle(color: Colors.red)),
             ),
           ],
        ),
     );

     if (confirm == true) {
        try {
            final prefs = await SharedPreferences.getInstance();
            const historyKey = 'download_history';
            await prefs.remove(historyKey); // Αφαίρεση του κλειδιού
            setState(() {
              _history = []; // Άδειασμα της λίστας στο UI
            });
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Download history cleared.')),
            );
        } catch (e) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing history: ${e.toString()}')),
          );
        }
     }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = const Center(child: Text('Download history is empty.'));

    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error: $_errorMessage', textAlign: TextAlign.center),
        ),
      );
    } else if (_history.isNotEmpty) {
      content = ListView.builder(
        itemCount: _history.length,
        itemBuilder: (ctx, index) {
          final entry = _history[index];
          final fileName = entry['fileName'] ?? 'Unknown File';
          final timestampStr = entry['timestamp'] ?? '';
          final pageIndex = entry['page'] ?? 0;
          String formattedDate = 'Invalid date';
          if (timestampStr.isNotEmpty) {
            try {
              final dateTime = DateTime.parse(timestampStr);
              // Μορφοποίηση: π.χ., "Mon, Jun 10, 2024 14:35" ή μια πιο τοπική μορφή
              formattedDate = DateFormat.yMd().add_Hm().format(dateTime);
            } catch (e) {
              // Handle parsing error if needed
              print("Error parsing date: $timestampStr");
            }
          }

          return ListTile(
            leading: const Icon(Icons.history),
            title: Text(fileName),
            subtitle: Text(
              'Downloaded: $formattedDate${pageIndex > 0 ? " (starts at page ${pageIndex + 1})" : ""}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            onTap: () => _openPdfFromHistory(entry),
             trailing: IconButton(
               icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
               tooltip: 'Remove from History',
               onPressed: () => _deleteHistoryEntry(index), // Κλήση διαγραφής για αυτή την εγγραφή
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Download History'),
         actions: [
          // Κουμπί για διαγραφή όλου του ιστορικού (αν υπάρχουν εγγραφές)
          if (_history.isNotEmpty && !_isLoading)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear All History',
              onPressed: _clearHistory,
            ),
          // Κουμπί ανανέωσης
          IconButton(
             icon: const Icon(Icons.refresh),
             tooltip: 'Refresh History',
             onPressed: _isLoading ? null : _loadHistory,
          ),
        ],
      ),
      body: content,
    );
  }
} 