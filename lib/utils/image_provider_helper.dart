import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';

/// Helper class for creating platform-aware image providers
class ImageProviderHelper {
  /// Get an appropriate image provider based on the path/URL
  /// On web, always uses NetworkImage for URLs
  /// On native, uses FileImage for local paths and NetworkImage for URLs
  static ImageProvider getImageProvider(String? path) {
    if (path == null || path.isEmpty) {
      // Return a transparent image provider as fallback
      return const AssetImage('assets/images/placeholder.png');
    }
    
    // Check if it's a URL
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    
    // On web, treat all non-URL paths as network images (shouldn't happen in practice)
    if (kIsWeb) {
      return NetworkImage(path);
    }
    
    // On native platforms, use FileImage for local paths
    return FileImage(File(path));
  }
  
  /// Check if an image exists (web-safe)
  /// On web, always returns true for URLs
  /// On native, checks file existence for local paths
  static Future<bool> imageExists(String? path) async {
    if (path == null || path.isEmpty) {
      return false;
    }
    
    // URLs are assumed to exist (we can't check without making a request)
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return true;
    }
    
    // On web, non-URL paths don't exist
    if (kIsWeb) {
      return false;
    }
    
    // On native platforms, check file existence
    try {
      return await File(path).exists();
    } catch (e) {
      return false;
    }
  }
  
  /// Get image widget with proper provider
  static Widget getImageWidget(
    String? path, {
    BoxFit? fit,
    double? width,
    double? height,
    Widget? errorWidget,
  }) {
    if (path == null || path.isEmpty) {
      return errorWidget ?? const SizedBox.shrink();
    }
    
    return Image(
      image: getImageProvider(path),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? const Icon(Icons.broken_image, size: 50);
      },
    );
  }
}

