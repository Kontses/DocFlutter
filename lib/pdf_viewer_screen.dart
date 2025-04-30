import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class PdfViewerScreen extends StatefulWidget {
  final String pdfPath;
  final String pdfName; // Για τον τίτλο

  const PdfViewerScreen({super.key, required this.pdfPath, required this.pdfName});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  int? pages = 0;
  int? currentPage = 0;
  bool isReady = false;
  String errorMessage = '';
  PDFViewController? _controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pdfName), // Εμφάνιση ονόματος αρχείου
      ),
      body: Stack(
        children: <Widget>[
          PDFView(
            filePath: widget.pdfPath,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: false,
            pageFling: true,
            pageSnap: true,
            defaultPage: currentPage!,
            fitPolicy: FitPolicy.BOTH,
            preventLinkNavigation: false, // Αν θέλετε να απενεργοποιήσετε links στο PDF
            onRender: (pages) {
              if (mounted) {
                 setState(() {
                   this.pages = pages;
                   isReady = true;
                 });
              }
            },
            onError: (error) {
               if (mounted) {
                  setState(() {
                    errorMessage = error.toString();
                  });
               }
              // print(error.toString());
            },
            onPageError: (page, error) {
               if (mounted) {
                  setState(() {
                    errorMessage = '$page: ${error.toString()}';
                  });
               }
              // print('$page: ${error.toString()}');
            },
            onViewCreated: (PDFViewController pdfViewController) {
              // Αποθήκευση controller για μελλοντική χρήση (π.χ. πλοήγηση σε σελίδα)
               _controller = pdfViewController;
            },
            onPageChanged: (int? page, int? total) {
              // print('page change: $page/$total');
               if (mounted) {
                  setState(() {
                    currentPage = page;
                  });
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
                )
        ],
      ),
      // Προαιρετικά: Floating Action Button για πλοήγηση σε σελίδα
      // floatingActionButton: FutureBuilder<
      //     PDFViewController?>( // Removed type arguments <PDFViewController>
      //   future: _controller, // Removed ?.future
      //   builder: (context, AsyncSnapshot<PDFViewController?> snapshot) {
      //     if (snapshot.hasData) {
      //       return FloatingActionButton.extended(
      //         label: Text("Go to page 5"),
      //         icon: Icon(Icons.arrow_forward_ios),
      //         onPressed: () async {
      //           await snapshot.data!.setPage(4); // page is 0-indexed
      //         },
      //       );
      //     }
      //     return Container();
      //   },
      // ),
    );
  }
} 