# API Integration Summary

## Overview
Updated Flutter app to integrate with the new authenticated backend API based on the OpenAPI specification v1.3.0.

## Changes Made

### 1. Created Base API Client (`lib/services/api_client.dart`)
- Centralized Dio client with automatic authentication header injection
- Automatically adds `Authorization: Bearer <token>` header when user is authenticated
- Adds `X-User-ID` header for all requests
- Handles 401 Unauthorized errors
- Provides convenience methods for GET, POST, PUT, DELETE, PATCH
- Includes file upload helpers for multipart/form-data

### 2. Updated Existing Services

#### ProjectsApiService
- ✅ Updated to use ApiClient for auth headers
- ✅ All endpoints now properly authenticated
- Endpoints: GET/POST `/projects`, GET/PUT/DELETE `/projects/{id}`, GET `/projects/{id}/overview`

#### ChatApiService  
- ✅ Updated to use ApiClient for auth headers
- ✅ File upload/download with authentication
- Endpoints: POST `/chat`, GET/POST `/projects/{id}/chat/sessions`, GET/POST/DELETE knowledge base files

#### FeedbackAnalysisService
- ✅ Updated to use ApiClient for auth headers
- Endpoints: POST/GET `/projects/{id}/feedback/analysis`, GET clusters/opportunities/mutation-briefs

#### MutationApiService
- ✅ Updated to use ApiClient for auth headers
- Endpoints: GET/POST/PUT/DELETE `/projects/{id}/mutations/{id}`

### 3. New Services Created

#### SubscriptionApiService (`lib/services/subscription_api_service.dart`)
- ✅ Manages user subscriptions and quotas
- **Public Endpoints:**
  - GET `/subscriptions/plans` - Get available subscription plans
- **Authenticated Endpoints:**
  - GET `/subscriptions/me` - Get current user's subscription
  - POST `/subscriptions/activate` - Activate subscription with discount code
  - GET `/subscriptions/quotas` - Get all quota statuses
  - GET `/subscriptions/quotas/{quota_type}` - Get specific quota status
- **Models:** SubscriptionPlan, UserSubscription, QuotaStatus
- **Mock Mode:** Full mock data support for development

## New API Endpoints Available (Not Yet Implemented)

### Image Assets API
Based on OpenAPI spec, these endpoints are available:
- `GET/POST /api/v1/{project_id}/assets` - List/create image assets
- `GET/PUT/DELETE /api/v1/assets/{asset_id}` - Manage specific assets
- `GET/POST /api/v1/assets/{asset_id}/generations` - Manage image generations
- `POST /api/v1/{project_id}/assets/extract` - Extract assets from content using LLM
- `POST /api/v1/{project_id}/assets/batch-create` - Batch create assets
- `POST /api/v1/{project_id}/assets/generate-prompt` - Generate optimized prompts using LLM
- `POST /api/v1/image-generation/generate` - Standalone image generation (quota enforced)

### SFX Assets API  
- `GET/POST /api/v1/{project_id}/sfx-assets` - List/create SFX assets
- `GET/PUT/DELETE /api/v1/sfx-assets/{asset_id}` - Manage specific assets
- `GET/POST /api/v1/sfx-assets/{asset_id}/generations` - Manage SFX generations (ElevenLabs)
- `POST /api/v1/{project_id}/sfx-assets/extract` - Extract SFX assets from content
- `POST /api/v1/{project_id}/sfx-assets/batch-create` - Batch create SFX assets
- `POST /api/v1/{project_id}/sfx-assets/generate-prompt` - Generate optimized prompts

### Music Assets API
- `GET/POST /api/v1/{project_id}/music-assets` - List/create music assets
- `GET/PUT/DELETE /api/v1/music-assets/{asset_id}` - Manage specific assets
- `GET/POST /api/v1/music-assets/{asset_id}/generations` - Manage music generations (ElevenLabs)
- `POST /api/v1/{project_id}/music-assets/generate-prompt` - Generate optimized prompts

### Admin Endpoints (Subscription Management)
- `POST/GET /api/v1/subscriptions/admin/discount-codes` - Create/list discount codes
- `GET/PATCH /api/v1/subscriptions/admin/discount-codes/{code}` - Manage specific codes

## Authentication Flow

### Header Injection
The `ApiClient` automatically handles authentication:

```dart
// In ApiClient interceptor
if (_authProvider?.isAuthenticated == true) {
  final session = Supabase.instance.client.auth.currentSession;
  if (session?.accessToken != null) {
    options.headers['authorization'] = 'Bearer ${session!.accessToken}';
  }
}

// Always add user ID
final userId = _authProvider?.userId ?? AppConstants.visitorUserId;
options.headers['X-User-ID'] = userId;
```

### Using Services
All services now require both SettingsProvider and AuthProvider:

```dart
final projectsService = ProjectsApiService(
  settingsProvider: settingsProvider,
  authProvider: authProvider,
);

// No need to manually add auth headers - handled automatically
final projects = await projectsService.getProjects();
```

## Migration Notes for Existing Code

### Before (Old Pattern)
```dart
final dio = Dio();
dio.options.headers['Authorization'] = 'Bearer $token'; // Manual
final response = await dio.get('$baseUrl/api/v1/projects');
```

### After (New Pattern)
```dart
final apiClient = ApiClient(
  settingsProvider: settingsProvider,
  authProvider: authProvider, // Auth added automatically
);
final response = await apiClient.get('/projects');
```

## Testing

### Mock Mode
All services support mock mode via `SettingsProvider.useMockMode`:
- When enabled, returns mock data without making network requests
- Useful for UI development and testing
- Mock data simulates real API responses

### Authentication Testing
- Services work with both authenticated and visitor (unauthenticated) users
- Visitor users use `AppConstants.visitorUserId` as their ID
- AuthProvider manages session state and provides user ID

## Next Steps

### To Complete Integration:
1. ✅ Base ApiClient with auth - DONE
2. ✅ Update existing services - DONE
3. ✅ Subscription API service - DONE
4. ⏳ Image Assets API service (if needed for your features)
5. ⏳ SFX Assets API service (if needed for your features)
6. ⏳ Music Assets API service (if needed for your features)
7. ⏳ Update UI components to use new quota system
8. ⏳ Add subscription management UI
9. ⏳ Test all authenticated endpoints
10. ⏳ Add error handling for quota exceeded scenarios

### Asset Management Services (Optional)
If you need the image/SFX/music asset management features, I can create those services following the same pattern. They would include:
- Asset CRUD operations
- Generation management
- Batch operations
- LLM-powered extraction and prompt generation
- File upload/download with authentication

### Code Quality
All updated files:
- ✅ Pass linter checks
- ✅ Follow existing code patterns
- ✅ Include proper error handling
- ✅ Support mock mode for development
- ✅ Include comprehensive documentation

## API Configuration

Current configuration in `lib/utils/app_constants.dart`:
```dart
class ApiConfig {
  static const String defaultBaseUrl = 'http://arcane-forge-service.dev.arcaneforge.ai';
  static const bool useApiService = true;
  
  static String get baseUrl {
    return dotenv.env['API_BASE_URL'] ?? defaultBaseUrl;
  }
  
  static bool get enabled {
    final useApiString = dotenv.env['USE_API_SERVICE']?.toLowerCase();
    return useApiString == 'true' || useApiService;
  }
}
```

## Error Handling

The ApiClient includes:
- Automatic retry for failed requests (via Dio interceptors)
- 401 Unauthorized detection
- Detailed error logging in development
- Graceful fallback to mock data when configured

## Performance Considerations

- Connection timeout: 30 seconds
- Receive timeout: 60 seconds (120s for analysis endpoints)
- Automatic request/response logging can be disabled in production
- File uploads include progress callbacks









