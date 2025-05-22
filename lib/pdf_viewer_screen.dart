import 'dart:io';
import 'dart:convert'; // Για JSON encoding/decoding
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Εισαγωγή
import 'package:flutter/services.dart';

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

  bool _areBarsVisible = true; // Νέα μεταβλητή για ορατότητα bars
  Timer? _visibilityTimer; // Νέος timer

  // Set για αποθήκευση των σελιδοδεικτών (0-indexed)
  Set<int> _bookmarkedPages = {};
  // Instance των SharedPreferences
  SharedPreferences? _prefs;

  // --- Μεταβλητές για τον custom slider ---
  double _sliderValue = 0.0; // 0.0 (top) to 1.0 (bottom)
  double _dragStartY = 0.0;
  double _dragStartSliderValue = 0.0;
  final double _sliderPadding = 10.0; // Padding πάνω/κάτω για το slider

  @override
  void initState() {
    super.initState();
    currentPage = widget.initialPage;
    _loadBookmarks();
    // Αρχικοποίηση _sliderValue με βάση την αρχική σελίδα
    // (Θα γίνει όταν φορτώσουν οι σελίδες στο onRender)

    // Επιτρέπουμε όλα τα orientations όταν ανοίγει το PDF
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _cancelVisibilityTimer(); // Ακύρωση timer
    // Επαναφέρουμε το προτιμώμενο orientation σε portrait όταν κλείνει το PDF
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
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
          // --- Τέλος Τροποποιήσεων AppBar ---
          title: Column( // Χρήση Column για τίτλο και σελίδες
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text(widget.pdfName, style: const TextStyle(fontSize: 16)),
             if(isReady) // Εμφάνιση σελίδων μόνο όταν είναι έτοιμο
               Text(pageInfo, style: const TextStyle(fontSize: 12)),
           ],
        ),
        // Προσθήκη action button για σελιδοδεικτή
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
           // Νέο κουμπί περιστροφής
           if (isReady)
             IconButton(
               icon: const Icon(Icons.screen_rotation),
               tooltip: 'Rotate Screen',
               onPressed: () {
                 final currentOrientation = MediaQuery.of(context).orientation;
                 if (currentOrientation == Orientation.portrait) {
                   SystemChrome.setPreferredOrientations([
                     DeviceOrientation.landscapeLeft,
                     DeviceOrientation.landscapeRight,
                   ]);
                 } else {
                   SystemChrome.setPreferredOrientations([
                     DeviceOrientation.portraitUp,
                     DeviceOrientation.portraitDown,
                   ]);
                 }
               },
             ),
           const SizedBox(width: 10), // Λίγο κενό δεξιά
        ],
      ),
      body: Stack( // Το Stack απευθείας
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
              preventLinkNavigation: false,
              onRender: (pagesValue) {
                if (mounted) {
                   setState(() {
                     pages = pagesValue ?? 0;
                     isReady = true;
                     int initialPageResolved = widget.initialPage;
                     if (initialPageResolved >= pages && pages > 0) {
                       initialPageResolved = pages - 1;
                     }
                     currentPage = initialPageResolved;
                     // Αρχικοποίηση _sliderValue εδώ
                     if (pages > 1) {
                       _sliderValue = currentPage / (pages - 1);
                     }
                     if (currentPage != widget.initialPage) {
                       _controller?.setPage(currentPage);
                     }

                     // Νέα λογική για έλεγχο orientation (αφαιρέθηκε)
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
                 if (mounted && page != null && pages > 1) {
                    setState(() {
                      currentPage = page;
                      // Ενημέρωση _sliderValue βάσει της νέας σελίδας
                      _sliderValue = page / (pages - 1);
                    });
                 }
              },
            ),
            // Τα υπόλοιπα παιδιά του Stack (Error message, etc.)
            errorMessage.isEmpty
                ? !isReady
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : Container()
                : Center(
                    child: Text(errorMessage),
                  ),

            // --- Custom Slider --- (Προστίθεται εδώ)
            if (isReady && pages > 1)
              Builder( // Χρήση Builder για να πάρουμε το σωστό context για το ύψος
                builder: (context) {
                  final appBarHeight = Scaffold.of(context).appBarMaxHeight; // Ύψος AppBar
                  final bottomBarHeight = MediaQuery.of(context).padding.bottom + // Ύψος κάτω padding
                                         (Scaffold.of(context).hasFloatingActionButton ? kFloatingActionButtonMargin : 0) +
                                         kBottomNavigationBarHeight; // Εκτίμηση για BottomAppBar (ή 0 αν δεν υπάρχει)
                  final availableHeight = MediaQuery.of(context).size.height -
                      (appBarHeight ?? kToolbarHeight) - // Fallback σε kToolbarHeight
                      (bottomBarHeight) -
                      (2 * _sliderPadding); // Αφαίρεση padding πάνω/κάτω

                  // Υπολογισμός θέσης 'top' για το εικονίδιο
                  final double sliderTopPosition = _sliderPadding + (_sliderValue * availableHeight);

                  return Positioned(
                    top: sliderTopPosition,
                    right: 5.0, // Μικρή απόσταση από τη δεξιά άκρη
                    child: GestureDetector(
                      onVerticalDragStart: (details) {
                        _dragStartY = details.globalPosition.dy;
                        _dragStartSliderValue = _sliderValue;
                      },
                      onVerticalDragUpdate: (details) {
                        if (availableHeight <= 0) return; // Αποφυγή διαίρεσης με μηδέν

                        final dragDeltaY = details.globalPosition.dy - _dragStartY;
                        final deltaRatio = dragDeltaY / availableHeight;
                        double newSliderValue = _dragStartSliderValue + deltaRatio;
                        newSliderValue = newSliderValue.clamp(0.0, 1.0);

                        // Υπολογισμός σελίδας
                        final targetPage = (newSliderValue * (pages - 1)).round();

                        // Άμεση πλοήγηση και ενημέρωση state
                        if (targetPage != currentPage && _controller != null) {
                          _controller!.setPage(targetPage);
                          // Ενημέρωση currentPage και _sliderValue
                          // για να μετακινηθεί το εικονίδιο άμεσα
                          setState(() {
                            currentPage = targetPage; // Ενημέρωση currentPage
                            _sliderValue = newSliderValue;
                          });
                        } else {
                          // Απλή ενημέρωση της θέσης του slider thumb αν η σελίδα δεν άλλαξε
                           setState(() {
                             _sliderValue = newSliderValue;
                           });
                        }
                      },
                      child: Icon(
                        Icons.drag_handle,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                        size: 28.0,
                      ),
                    ),
                  );
                },
              ),
            // --- Τέλος Custom Slider ---
          ],
        ),
        // Μετακίνηση BottomAppBar εντός Scaffold
        bottomNavigationBar: isReady && pages > 1
            ? BottomAppBar(
                height: 48.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Previous Page',
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
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
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
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
      ),
    );
  }
}
