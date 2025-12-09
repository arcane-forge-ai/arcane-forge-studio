import 'dart:async';
import 'dart:typed_data';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:file_picker/file_picker.dart';

Future<List<PlatformFile>?> pickFilesWithWebFallback({
  required List<String> allowedExtensions,
  required bool allowMultiple,
}) async {
  final completer = Completer<List<PlatformFile>?>();
  final input = html.FileUploadInputElement()
    ..multiple = allowMultiple
    ..accept = allowedExtensions.map((ext) => '.$ext').join(',');

  input.onChange.listen((event) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }

    final platformFiles = await Future.wait(files.map((file) async {
      final reader = html.FileReader();
      final readCompleter = Completer<Uint8List>();
      reader.onLoadEnd.listen((event) {
        final result = reader.result;
        if (result is Uint8List) {
          readCompleter.complete(result);
        } else if (result is ByteBuffer) {
          readCompleter.complete(result.asUint8List());
        } else {
          readCompleter.complete(Uint8List(0));
        }
      });
      reader.readAsArrayBuffer(file);
      final bytes = await readCompleter.future;
      return PlatformFile(
        name: file.name,
        size: bytes.length,
        bytes: bytes,
        path: null,
      );
    }));

    completer.complete(platformFiles);
  });

  input.click();
  return completer.future;
}
