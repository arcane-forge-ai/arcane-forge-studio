import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/download_models.dart';

class A1111InstallerService {
  A1111InstallerService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Check if A1111 is already installed
  Future<bool> isInstalled(Directory baseDir) async {
    final targetDir = Directory(p.join(baseDir.path, 'automatic1111'));
    if (!await targetDir.exists()) return false;
    
    // Check if directory has any files (not just empty)
    final hasFiles = await targetDir.list().isEmpty.then((empty) => !empty);
    debugPrint('🔍 A1111 installation check: ${hasFiles ? "FOUND" : "EMPTY"}');
    return hasFiles;
  }

  Future<void> downloadAndInstall({
    required String url,
    required Directory baseDir,
    required void Function(InstallerProgress) onProgress,
    CancelToken? cancelToken,
  }) async {
    debugPrint('📦 Starting A1111 download/install from: $url');
    
    // Ensure base directory exists
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
      debugPrint('📁 Created base directory: ${baseDir.path}');
    }

    final fileName = _fileNameFromUrl(url);
    final partPath = p.join(baseDir.path, '$fileName.part');
    final finalZipPath = p.join(baseDir.path, fileName);
    final partFile = File(partPath);
    final finalZipFile = File(finalZipPath);
    final targetDir = Directory(p.join(baseDir.path, 'automatic1111'));

    // Check if zip already exists (resume from extraction)
    if (await finalZipFile.exists()) {
      final zipSize = await finalZipFile.length();
      debugPrint('✅ Zip already downloaded ($zipSize bytes), skipping to extraction');
      await _extractArchive(finalZipPath, targetDir, onProgress);
      return;
    }

    int existingLength = 0;
    if (await partFile.exists()) {
      existingLength = await partFile.length();
      debugPrint('🔄 Resuming download from $existingLength bytes');
    }

    onProgress(const InstallerProgress(InstallerStatus.downloading));
    debugPrint('⬇️  Starting download...');

    // Open sink in append mode to support resume
    final sink = partFile.openWrite(mode: FileMode.append);
    try {
      final response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: existingLength > 0 ? {'Range': 'bytes=$existingLength-'} : null,
        ),
        cancelToken: cancelToken,
      );

      final totalFromServer = _parseContentRangeTotal(
        response.headers['content-range']?.firstOrNull,
        response.headers[Headers.contentLengthHeader]?.firstOrNull,
        existingLength,
      );

      int receivedThisSession = 0;
      final stream = response.data!.stream;
      final completer = Completer<void>();

      final subscription = stream.listen(
        (chunk) {
          sink.add(chunk);
          receivedThisSession += chunk.length;
          final received = existingLength + receivedThisSession;
          final double? fraction = totalFromServer != null && totalFromServer > 0
              ? received / totalFromServer
              : null;
          onProgress(InstallerProgress(
            InstallerStatus.downloading,
            fraction: fraction,
            receivedBytes: received,
            totalBytes: totalFromServer,
          ));
        },
        onDone: () => completer.complete(),
        onError: (e, st) => completer.completeError(e, st),
        cancelOnError: true,
      );

      await completer.future;
      await subscription.cancel();
    } on DioException catch (e) {
      onProgress(InstallerProgress(InstallerStatus.error, message: e.message));
      await sink.flush();
      await sink.close();
      rethrow;
    } catch (e) {
      onProgress(InstallerProgress(InstallerStatus.error, message: e.toString()));
      await sink.flush();
      await sink.close();
      rethrow;
    }

    await sink.flush();
    await sink.close();

    // Rename part file to final .zip
    if (await finalZipFile.exists()) {
      await finalZipFile.delete();
    }
    await partFile.rename(finalZipPath);
    final zipSize = await finalZipFile.length();
    debugPrint('✅ Download complete: $zipSize bytes saved to $finalZipPath');

    // Extract archive
    await _extractArchive(finalZipPath, targetDir, onProgress);
  }

  Future<void> _extractArchive(
    String zipPath,
    Directory targetDir,
    void Function(InstallerProgress) onProgress,
  ) async {
    onProgress(const InstallerProgress(InstallerStatus.extracting));
    debugPrint('📂 Starting extraction to: ${targetDir.path}');
    
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
      debugPrint('📁 Created target directory');
    }

    try {
      await Isolate.run(() {
        debugPrint('🔄 [Isolate] Opening zip file: $zipPath');
        final bytes = File(zipPath).readAsBytesSync();
        debugPrint('🔄 [Isolate] Read ${bytes.length} bytes from zip file');
        
        try {
          debugPrint('🔄 [Isolate] Decoding archive with verify: false...');
          // Use verify: false to handle non-UTF-8 filenames gracefully
          final archive = ZipDecoder().decodeBytes(bytes, verify: false);
          debugPrint('🔄 [Isolate] Archive has ${archive.files.length} files');
          
          // Check first few file paths to understand structure
          if (archive.files.isNotEmpty) {
            debugPrint('🔍 [Isolate] Sample files from archive:');
            for (var i = 0; i < (archive.files.length < 5 ? archive.files.length : 5); i++) {
              debugPrint('  - ${archive.files[i].name} (${archive.files[i].isFile ? "file" : "dir"})');
            }
          }
          
          debugPrint('🔄 [Isolate] Extracting to disk: ${targetDir.path}');
          
          // Manual extraction with error handling per file
          var extractedCount = 0;
          var skippedCount = 0;
          for (final file in archive.files) {
            try {
              final filename = file.name;
              if (file.isFile) {
                final data = file.content as List<int>;
                final outFile = File(p.join(targetDir.path, filename));
                outFile.createSync(recursive: true);
                outFile.writeAsBytesSync(data);
                extractedCount++;
                if (extractedCount % 5000 == 0) {
                  debugPrint('🔄 [Isolate] Extracted $extractedCount files...');
                }
              } else {
                Directory(p.join(targetDir.path, filename)).createSync(recursive: true);
                skippedCount++;
              }
            } catch (e) {
              debugPrint('⚠️ [Isolate] Failed to extract ${file.name}: $e');
            }
          }
          debugPrint('✅ [Isolate] Extraction complete: $extractedCount files, $skippedCount directories');
        } catch (e) {
          debugPrint('❌ [Isolate] Decoding error: $e');
          rethrow;
        }
      });
      
      // Verify extraction
      final extractedFiles = await targetDir.list(recursive: true).length;
      debugPrint('✅ Extraction verified: $extractedFiles files/dirs in ${targetDir.path}');
      
      onProgress(const InstallerProgress(InstallerStatus.completed));
    } catch (e, st) {
      debugPrint('❌ Extraction failed: $e');
      debugPrint('Stack trace: $st');
      onProgress(InstallerProgress(InstallerStatus.error, message: 'Extraction failed: $e'));
      rethrow;
    }
  }

  String _fileNameFromUrl(String url) {
    final uri = Uri.parse(url);
    final name = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'a1111.zip';
    return name.endsWith('.zip') ? name : '$name.zip';
  }

  int? _parseContentRangeTotal(String? contentRange, String? contentLength, int existing) {
    // Try Content-Range: bytes <start>-<end>/<total>
    if (contentRange != null) {
      final slashIdx = contentRange.lastIndexOf('/');
      if (slashIdx != -1) {
        final totalStr = contentRange.substring(slashIdx + 1).trim();
        final total = int.tryParse(totalStr);
        if (total != null) return total;
      }
    }
    // Fall back to Content-Length + existing
    final len = int.tryParse(contentLength ?? '');
    if (len != null) return len + existing;
    return null;
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}


