import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';

class BookStorage {
  const BookStorage();

  Future<Directory> _booksDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}${Platform.pathSeparator}books');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<File> fileFor(int bookId) async {
    final directory = await _booksDirectory();
    return File('${directory.path}${Platform.pathSeparator}book_$bookId.pdf');
  }

  Future<bool> isDownloaded(int bookId) async {
    final file = await fileFor(bookId);
    if (!await file.exists()) return false;
    return await file.length() > 5;
  }

  Future<String?> localPath(int bookId) async {
    final file = await fileFor(bookId);
    return await isDownloaded(bookId) ? file.path : null;
  }

  Future<String> download({
    required int bookId,
    required String url,
    void Function(int received, int total)? onProgress,
  }) async {
    final target = await fileFor(bookId);
    final partial = File('${target.path}.download');
    if (await partial.exists()) await partial.delete();

    final client = http.Client();
    try {
      final response = await client
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(const Duration(seconds: 25));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const ApiException('تعذر تنزيل الكتاب من الخادم.');
      }
      final sink = partial.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, response.contentLength ?? 0);
        }
      } finally {
        await sink.close();
      }
      final bytes = await partial
          .openRead(0, 5)
          .fold<List<int>>(<int>[], (value, chunk) => value..addAll(chunk));
      if (String.fromCharCodes(bytes) != '%PDF-') {
        await partial.delete();
        throw const ApiException('الملف المستلم ليس كتاب PDF صالحًا.');
      }
      if (await target.exists()) await target.delete();
      await partial.rename(target.path);
      return target.path;
    } on ApiException {
      rethrow;
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      throw const ApiException(
        'انقطع تنزيل الكتاب. تحقق من الإنترنت ثم حاول مجددًا.',
      );
    } finally {
      client.close();
    }
  }

  Future<void> delete(int bookId) async {
    final file = await fileFor(bookId);
    if (await file.exists()) await file.delete();
  }
}
