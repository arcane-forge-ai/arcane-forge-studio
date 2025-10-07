import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized application constants and utilities
class AppConstants {
  /// UUID for visitor mode - centralized so we can easily change it if needed
  static const String visitorUserId = '00000000-0000-0000-0000-000000000000';

  /// Default output directory for all generated contents
  static const String defaultOutputDirectory = 'output';
}

/// Image Generation Backend Types
enum ImageGenerationBackend {
  automatic1111('Automatic1111'),
  comfyui('ComfyUI'),
  sora('Sora (ChatGPT)'),
  gemini('Gemini');

  const ImageGenerationBackend(this.displayName);
  final String displayName;
}

/// Image generation configuration constants
class ImageGenerationConstants {
  /// Default backend
  static const ImageGenerationBackend defaultBackend = ImageGenerationBackend.automatic1111;
  
  /// Default commands for each backend
  static const Map<ImageGenerationBackend, String> defaultCommands = {
    ImageGenerationBackend.automatic1111: r'python\\python.exe launch.py --theme light --xformers --api --autolaunch --server-name 0.0.0.0 --skip-python-version-check --lyco-dir H:\\sd-webui-aki-v4.8\\models\\LyCORIS --skip-install',
    ImageGenerationBackend.comfyui: r'python_embeded\\python.exe -s ComfyUI\\main.py --windows-standalone-build --fast fp16_accumulation',
  };
  
  /// Default working directories for each backend
  static const Map<ImageGenerationBackend, String> defaultWorkingDirectories = {
    ImageGenerationBackend.automatic1111: r'H:\\sd-webui-aki-v4.8',
    ImageGenerationBackend.comfyui: r'H:\\ComfyUI_windows_portable_nvidia\\ComfyUI_windows_portable',
  };
  
  /// Default API endpoints for each backend
  static const Map<ImageGenerationBackend, String> defaultEndpoints = {
    ImageGenerationBackend.automatic1111: 'http://127.0.0.1:7860',
    ImageGenerationBackend.comfyui: 'http://127.0.0.1:8188',
  };
  
  /// Default API health check endpoints for each backend
  static const Map<ImageGenerationBackend, String> defaultHealthCheckEndpoints = {
    ImageGenerationBackend.automatic1111: '/app_id',
    ImageGenerationBackend.comfyui: '/app_id',
  };
  
  /// Default WebSocket endpoints for each backend
  static const Map<ImageGenerationBackend, String> defaultWebSocketEndpoints = {
    ImageGenerationBackend.automatic1111: 'ws://127.0.0.1:7860',
    ImageGenerationBackend.comfyui: 'ws://127.0.0.1:8188',
  };
  
  /// Default generation parameters for each backend
  static const Map<ImageGenerationBackend, Map<String, dynamic>> defaultGenerationParams = {
    ImageGenerationBackend.automatic1111: {
      'width': 512,
      'height': 512,
      'steps': 20,
      'cfg_scale': 7.5,
      'sampler_name': 'DPM++ 2M Karras',
      'batch_size': 1,
      'n_iter': 1,
    },
    ImageGenerationBackend.comfyui: {
      'width': 512,
      'height': 512,
      'steps': 20,
      'cfg_scale': 7.5,
      'sampler_name': 'euler',
      'batch_size': 1,
    },
  };
  
  /// Common dimension options
  static const List<Map<String, int>> commonDimensions = [
    {'width': 512, 'height': 512},
    {'width': 768, 'height': 768},
    {'width': 1024, 'height': 1024},
    {'width': 512, 'height': 768},
    {'width': 768, 'height': 512},
    {'width': 1024, 'height': 768},
    {'width': 768, 'height': 1024},
  ];
}

/// Date formatting utilities
class DateUtils {
  /// Standard date format: yyyy/mm/dd
  static final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  
  /// Standard datetime format: yyyy/mm/dd HH:mm
  static final DateFormat _dateTimeFormat = DateFormat('yyyy/MM/dd HH:mm');
  
  /// Format DateTime to standard date string (yyyy/mm/dd)
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }
  
  /// Format DateTime to standard datetime string (yyyy/mm/dd HH:mm)
  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }
  
  /// Format date string to standard format (yyyy/mm/dd)
  /// Used for parsing ISO strings from APIs like Supabase
  static String formatDateString(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return formatDate(date);
    } catch (e) {
      return 'Invalid date';
    }
  }
  
  /// Format datetime string to standard format (yyyy/mm/dd HH:mm)
  /// Used for parsing ISO strings from APIs like Supabase
  static String formatDateTimeString(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return formatDateTime(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }
  
  static DateTime? parseDateTime(String dateTimeString) {
    try {
      return _dateTimeFormat.parse(dateTimeString);
    } catch (e) {
      return null;
    }
  }
} 

// API Configuration
class ApiConfig {
  static const String defaultBaseUrl = 'http://arcane-forge-service.dev.arcaneforge.ai';
  static const bool useApiService = true; // Set to false to use mock service
  
  // Environment-based configuration
  static String get baseUrl {
    return dotenv.env['API_BASE_URL'] ?? defaultBaseUrl;
  }
  
  static bool get enabled {
    final useApiString = dotenv.env['USE_API_SERVICE']?.toLowerCase();
    return useApiString == 'true' || useApiService;
  }
} 