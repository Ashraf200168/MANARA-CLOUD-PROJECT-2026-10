import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class BookReaderScreen extends StatelessWidget {
  const BookReaderScreen({super.key, required this.title, required this.path});

  final String title;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: PdfViewer.file(
        path,
        params: const PdfViewerParams(
          textSelectionParams: PdfTextSelectionParams(),
          margin: 8,
          backgroundColor: Color(0xFFEAF2F6),
        ),
      ),
    );
  }
}
