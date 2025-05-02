import 'dart:io';
import 'dart:convert'; // Για JSON encoding/decoding
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Εισαγωγή

class PdfViewerScreen extends StatefulWidget {
  final String pdfPath;
  final String pdfName; // Για τον τίτλο
  // Προαιρετικός παράμετρος για αρχική σελίδα (0-indexed)
  final int initialPage;

  const PdfViewerScreen({
    super.key,
    required this.pdfPath,
    required this.pdfName,
    this.initialPage = 0, // Προεπιλογή 0 αν δεν δοθεί
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  int pages = 0; // Αρχικοποίηση σε 0
  late int currentPage; // Θα αρχικοποιηθεί στο initState
  bool isReady = false;
  String errorMessage = '';
  PDFViewController? _controller;
  // Μεταβλητή για να ξέρουμε αν ο χρήστης σύρει το slider
  bool _isSliderScrolling = false;

  // Set για αποθήκευση των σελιδοδεικτών (0-indexed)
  Set<int> _bookmarkedPages = {};
  // Instance των SharedPreferences
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    // Αρχικοποίηση currentPage με βάση το widget.initialPage
    currentPage = widget.initialPage;
    _loadBookmarks(); // Φόρτωση σελιδοδεικτών κατά την έναρξη
  }

  // Συνάρτηση για φόρτωση σελιδοδεικτών
  Future<void> _loadBookmarks() async {
    _prefs = await SharedPreferences.getInstance();
    // Χρήση του ονόματος αρχείου ως μέρος του κλειδιού
    final String key = 'bookmarks_${widget.pdfName}';
    final String? bookmarksJson = _prefs?.getString(key);
    if (bookmarksJson != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(bookmarksJson);
        if (mounted) { // Έλεγχος αν το widget είναι ακόμα στο tree
           setState(() {
              // Μετατροπή από dynamic list σε Set<int>
             _bookmarkedPages = decodedList.cast<int>().toSet();
           });
        }
      } catch (e) {
        print("Error loading bookmarks: $e");
        // Προαιρετικά: Διαγραφή λανθασμένου κλειδιού
        // await _prefs?.remove(key);
      }
    }
  }

  // Συνάρτηση για αποθήκευση σελιδοδεικτών
  Future<void> _saveBookmarks() async {
    if (_prefs == null) return;
    final String key = 'bookmarks_${widget.pdfName}';
    // Μετατροπή του Set<int> σε List<int> και μετά σε JSON String
    final String bookmarksJson = jsonEncode(_bookmarkedPages.toList());
    await _prefs?.setString(key, bookmarksJson);
  }

  // Συνάρτηση για προσθήκη/αφαίρεση σελιδοδείκτη
  void _toggleBookmark() {
    setState(() {
      if (_bookmarkedPages.contains(currentPage)) {
        _bookmarkedPages.remove(currentPage);
      } else {
        _bookmarkedPages.add(currentPage);
      }
    });
    _saveBookmarks(); // Αποθήκευση μετά την αλλαγή
  }

  // Συνάρτηση για εμφάνιση λίστας σελιδοδεικτών
  void _showBookmarksDialog() {
    if (_bookmarkedPages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved bookmarks found.')),
      );
      return;
    }

    // Ταξινόμηση σελίδων για εμφάνιση
    final sortedBookmarks = _bookmarkedPages.toList()..sort();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bookmarks'),
        content: SizedBox(
          width: double.maxFinite, // Για να γεμίσει το πλάτος
          child: ListView.builder(
            shrinkWrap: true, // Να παίρνει μόνο τον απαραίτητο χώρο κάθετα
            itemCount: sortedBookmarks.length,
            itemBuilder: (context, index) {
              final pageIndex = sortedBookmarks[index]; // 0-indexed
              final pageNumber = pageIndex + 1; // 1-indexed για εμφάνιση
              return ListTile(
                title: Text('Page $pageNumber'),
                onTap: () {
                  _controller?.setPage(pageIndex); // Πλοήγηση στη σελίδα (0-indexed)
                  Navigator.of(context).pop(); // Κλείσιμο διαλόγου
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageInfo = isReady ? 'Page ${currentPage + 1} / $pages' : 'Loading...';
    // Έλεγχος αν η τρέχουσα σελίδα είναι σελιδοδείκτης
    final bool isCurrentPageBookmarked = _bookmarkedPages.contains(currentPage);

    return Scaffold(
      appBar: AppBar(
        title: Column( // Χρήση Column για τίτλο και σελίδες
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text(widget.pdfName, style: const TextStyle(fontSize: 16)),
             if(isReady) // Εμφάνιση σελίδων μόνο όταν είναι έτοιμο
               Text(pageInfo, style: const TextStyle(fontSize: 12)),
           ],
        ),
        // Προσθήκη action button για σελιδοδείκτη
        actions: [
          // Κουμπί για εμφάνιση λίστας σελιδοδεικτών
          if (isReady && _bookmarkedPages.isNotEmpty) // Εμφάνιση μόνο αν υπάρχουν σελιδοδείκτες
             IconButton(
               icon: const Icon(Icons.bookmarks),
               tooltip: 'View Bookmarks',
               onPressed: _showBookmarksDialog,
             ),
          // Κουμπί για εναλλαγή σελιδοδείκτη τρέχουσας σελίδας
          if (isReady)
             IconButton(
               icon: Icon(
                 isCurrentPageBookmarked ? Icons.bookmark : Icons.bookmark_border,
               ),
               tooltip: isCurrentPageBookmarked
                   ? 'Remove Bookmark'
                   : 'Add Bookmark',
               onPressed: _toggleBookmark,
             ),
           const SizedBox(width: 10), // Λίγο κενό δεξιά
        ],
      ),
      body: Stack( // Χρήση Stack για το PDF και το Slider
        children: <Widget>[
          PDFView(
            filePath: widget.pdfPath,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: false,
            pageFling: true,
            pageSnap: false,
            defaultPage: currentPage,
            fitPolicy: FitPolicy.WIDTH,
            preventLinkNavigation: false, // Αν θέλετε να απενεργοποιήσετε links στο PDF
            onRender: (pagesValue) {
              if (mounted) {
                 setState(() {
                   pages = pagesValue ?? 0;
                   isReady = true;
                   // Διασφάλιση ότι η αρχική σελίδα είναι εντός ορίων
                   if (widget.initialPage >= pages) {
                       currentPage = pages > 0 ? pages - 1 : 0;
                       _controller?.setPage(currentPage);
                   }
                 });
              }
            },
            onError: (error) {
               if (mounted) {
                  setState(() {
                    errorMessage = error.toString();
                  });
               }
            },
            onPageError: (page, error) {
               if (mounted) {
                  setState(() {
                    errorMessage = '$page: ${error.toString()}';
                  });
               }
            },
            onViewCreated: (PDFViewController pdfViewController) {
               _controller = pdfViewController;
            },
            onPageChanged: (int? page, int? total) {
               if (mounted && page != null) {
                 // Αλλάζουμε το state μόνο αν δεν σύρουμε το slider
                 // ή αν η κατάσταση σελιδοδείκτη άλλαξε (για να ανανεωθεί το εικονίδιο)
                 if (!_isSliderScrolling) {
                    setState(() {
                       currentPage = page;
                       // Δεν χρειάζεται να ξαναδιαβάσουμε τα bookmarks εδώ,
                       // η κατάσταση του isCurrentPageBookmarked θα ενημερωθεί
                       // αυτόματα στην επόμενη κλήση του build.
                    });
                 } else {
                   // Ακόμα κι αν σύρουμε το slider, θέλουμε το AppBar icon
                   // να ενημερωθεί αν αλλάξει η σελίδα
                   setState(() {
                     currentPage = page;
                   });
                 }
               }
            },
          ),
          errorMessage.isEmpty
              ? !isReady
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : Container()
              : Center(
                  child: Text(errorMessage),
                ),
           // Κάθετος Slider στη δεξιά πλευρά (πάνω από το PDF)
           if(isReady && pages > 1)
             Positioned(
               right: 0,
               top: 10, // Λίγο κενό πάνω
               bottom: 10, // Λίγο κενό κάτω
               width: 40, // Πλάτος για να πιάνει το touch
               child: RotatedBox(
                 quarterTurns: 1, // Περιστροφή για να γίνει κάθετο
                 child: SliderTheme(
                    // Προσαρμογή εμφάνισης slider
                   data: SliderTheme.of(context).copyWith(
                     activeTrackColor: Colors.transparent, // Αόρατη γραμμή (ενεργή)
                     inactiveTrackColor: Colors.transparent, // Αόρατη γραμμή (ανενεργή)
                     thumbColor: Colors.blue.withOpacity(0.7), // Χρώμα δείκτη με διαφάνεια
                     overlayColor: Colors.blue.withOpacity(0.2), // Χρώμα γύρω από τον δείκτη όταν πατιέται
                     trackHeight: 2.0, // Μπορεί να χρειάζεται μικρό ύψος για να πιάνει το touch
                   ),
                   child: Slider(
                     value: currentPage.toDouble(),
                     min: 0,
                     max: (pages - 1).toDouble(),
                     // divisions: pages > 1 ? pages - 1 : 1, // Αφαίρεση divisions για πιο ομαλό scroll
                     label: 'Page ${(currentPage + 1)}', // Ετικέτα που εμφανίζεται κατά το σύρσιμο
                     // Όταν ξεκινά το σύρσιμο
                     onChangeStart: (double value) {
                        setState(() {
                          _isSliderScrolling = true;
                        });
                     },
                     // Καθώς αλλάζει η τιμή (σύρσιμο)
                     onChanged: (double value) {
                       final newPage = value.round();
                       // Αλλάζουμε τοπικά το state για άμεση απόκριση του slider
                       setState(() {
                           currentPage = newPage;
                       });
                     },
                     // Όταν τελειώνει το σύρσιμο
                     onChangeEnd: (double value) {
                       final newPage = value.round();
                       _controller?.setPage(newPage); // Ορίζουμε τη σελίδα στο PDF controller
                       // Περιμένουμε λίγο πριν επιτρέψουμε ξανά στο onPageChanged να αλλάξει το state,
                       // για να αποφύγουμε το τρεμόπαιγμα
                       Future.delayed(const Duration(milliseconds: 200), () {
                          if(mounted) {
                              setState(() {
                                _isSliderScrolling = false;
                              });
                          }
                       });
                     },
                   ),
                 ),
               ),
             ),
        ],
      ),
      // Επαναφορά του αρχικού BottomAppBar
      bottomNavigationBar: isReady && pages > 1
        ? BottomAppBar(
            // Ορισμός μικρότερου ύψους
            height: 48.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous Page',
                  onPressed: currentPage > 0
                      ? () {
                          _controller?.setPage(currentPage - 1);
                        }
                      : null,
                ),
                Text(pageInfo, style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next Page',
                  onPressed: currentPage < pages - 1
                      ? () {
                          _controller?.setPage(currentPage + 1);
                        }
                      : null,
                ),
              ],
            ),
          )
        : null,
    );
  }
} 