// Conditional export for platform-specific A1111 installer implementations
// Uses dart:io implementation on native platforms, web stub on web
export 'a1111_installer_service_io.dart'
    if (dart.library.html) 'a1111_installer_service_web.dart';

