# Environment Configuration

This Flutter app uses environment variables to configure API endpoints and other settings for different environments (development, staging, production).

## Setup

1. **Copy the example file:**
   ```bash
   cp .env.example .env
   ```

2. **Configure your environment variables in `.env`:**
   ```bash
   # API Configuration
   API_BASE_URL=http://localhost:8000
   DEFAULT_USER_ID=00000000-0000-0000-0000-000000000000

   # Supabase
   SUPABASE_URL=https://your-supabase-url.supabase.co
   SUPABASE_ANON_KEY=your-supabase-anon-key
   
   # Environment
   ENVIRONMENT=development
   ```

## Environment Variables

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `API_BASE_URL` | The base URL for your FastAPI backend | `http://localhost:8000` |
| `DEFAULT_USER_ID` | Default user ID for API requests (UUID format for visitors) | `00000000-0000-0000-0000-000000000000` |
| `ENVIRONMENT` | Current environment (development, staging, production) | `development` |
| `SUPABASE_URL` | Your Supabase project URL | `https://your-supabase-url.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase anonymous key | `your-supabase-anon-key` |

## Different Environments

### Development
```bash
API_BASE_URL=http://localhost:8000
DEFAULT_USER_ID=00000000-0000-0000-0000-000000000000
ENVIRONMENT=development
```

### Staging
```bash
API_BASE_URL=https://your-staging-api.com
DEFAULT_USER_ID=00000000-0000-0000-0000-000000000000
ENVIRONMENT=staging
```

### Production
```bash
API_BASE_URL=https://your-production-api.com
DEFAULT_USER_ID=00000000-0000-0000-0000-000000000000
ENVIRONMENT=production
```

## Important Notes

- The `.env` file is ignored by git for security reasons
- Always use `.env.example` as a template for new environments
- Environment variables are loaded at app startup
- If `.env` file is missing, the app will use fallback defaults
- Changes to `.env` require an app restart to take effect
- **DEFAULT_USER_ID must be in UUID format** - the API expects valid UUIDs for user identification

## Usage in Code

Environment variables are accessed through the `ProjectsApiService`:

```dart
// The service automatically reads from environment variables
final projects = await ProjectsApiService.getProjects();

// You can also override the user ID if needed (must be UUID format)
final projects = await ProjectsApiService.getProjects(userId: "user-uuid-here");
``` 