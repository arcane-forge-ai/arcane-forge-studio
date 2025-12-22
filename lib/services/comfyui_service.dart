// Conditional export for platform-specific AI image generation service implementations
// Uses dart:io implementation on native platforms, web-safe stub on web
export 'comfyui_service_io.dart'
    if (dart.library.html) 'comfyui_service_web.dart';

