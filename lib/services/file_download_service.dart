import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';
import 'file_download_web_stub.dart'
    if (dart.library.html) 'file_download_web.dart';

/// Configuration for file download
class FileDownloadConfig {
  final String dialogTitle;
  final List<String> allowedExtensions;
  final String errorPrefix; // e.g., "Error downloading audio"
  final Color downloadingSnackbarColor;
  final bool showOverwriteConfirmation;

  const FileDownloadConfig({
    required this.dialogTitle,
    required this.allowedExtensions,
    required this.errorPrefix,
    this.downloadingSnackbarColor = Colors.blue,
    this.showOverwriteConfirmation = true,
  });
}

/// Service for downloading files from URLs
class FileDownloadService {
  /// Downloads a file from a URL and saves it to a user-selected location
  /// 
  /// [url] - The URL of the file to download
  /// [defaultFileName] - Suggested filename for the save dialog
  /// [config] - Configuration for the download (file types, messages, etc.)
  /// [context] - BuildContext for showing dialogs and snackbars
  /// [mounted] - Optional callback to check if widget is still mounted
  /// 
  /// Returns true if download was successful, false otherwise
  static Future<bool> downloadFile({
    required String url,
    required String defaultFileName,
    required FileDownloadConfig config,
    required BuildContext context,
    bool Function()? mounted,
  }) async {
    // Store ScaffoldMessenger before async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (url.isEmpty) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('No ${config.errorPrefix.toLowerCase().replaceFirst('error downloading ', '')} URL available for download'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    try {
      if (kIsWeb) {
        // Show downloading indicator with web-specific copy
        if (mounted == null || mounted()) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                'Downloading $defaultFileName... (browser will save to its default location; no overwrite prompt)',
              ),
              backgroundColor: config.downloadingSnackbarColor,
            ),
          );
        }

        // Download file content using dio
        final dio = Dio();
        final response = await dio.get(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(minutes: 5),
          ),
        );

        triggerWebDownload(Uint8List.fromList(response.data), defaultFileName);

        if (mounted == null || mounted()) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Saved "$defaultFileName" via browser download'),
              backgroundColor: Colors.green,
            ),
          );
        }

        return true;
      }

      // Show "Save As" dialog (desktop)
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: config.dialogTitle,
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: config.allowedExtensions,
      );

      if (outputFile == null) {
        // User cancelled the dialog
        return false;
      }

      // Check if file already exists and confirm overwrite
      final outputFileObj = File(outputFile);
      if (config.showOverwriteConfirmation && await outputFileObj.exists()) {
        // Check mounted before showing dialog
        if (mounted != null && !mounted()) return false;

        final shouldOverwrite = await _showOverwriteConfirmDialog(
          context,
          outputFileObj.path,
        );
        if (!shouldOverwrite) {
          return false;
        }
      }

      // Show downloading indicator
      if (mounted == null || mounted()) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Downloading $defaultFileName...'),
            backgroundColor: config.downloadingSnackbarColor,
          ),
        );
      }

      // Download file content using dio
      final dio = Dio();
      final response = await dio.get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 5), // 5 minute timeout for large files
        ),
      );

      // Write to selected location
      await outputFileObj.writeAsBytes(response.data);

      // Show success message with file location
      if (mounted == null || mounted()) {
        final fileName = outputFileObj.path.split(Platform.pathSeparator).last;
        final directory = outputFileObj.parent.path;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Saved "$fileName" to $directory'),
            backgroundColor: Colors.green,
          ),
        );
      }

      return true;
    } catch (e) {
      if (mounted != null && !mounted()) return false;

      String errorMessage = '${config.errorPrefix}: ';
      if (e is DioException) {
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.receiveTimeout:
            errorMessage += 'Download timed out. Please try again.';
            break;
          case DioExceptionType.connectionError:
            errorMessage += 'Network connection error.';
            break;
          default:
            errorMessage += e.message ?? 'Unknown network error';
        }
      } else if (e is FileSystemException) {
        errorMessage += 'Could not save file. Check permissions and disk space.';
      } else {
        errorMessage += e.toString();
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );

      return false;
    }
  }

  static Future<bool> _showOverwriteConfirmDialog(
    BuildContext context,
    String filePath,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'File Already Exists',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'The file "$filePath" already exists. Do you want to overwrite it?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Overwrite'),
          ),
        ],
      ),
    ) ?? false;
  }
}

