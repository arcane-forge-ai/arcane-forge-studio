# Subscription System - Troubleshooting Guide

## Summary of Fixes Applied

### Issue 1: Quota Widget Not Visible ✅ FIXED
**Problem**: QuotaStatusWidget was returning empty widget when subscription wasn't initialized.

**Solution**: Added loading state indicator while subscription initializes:
```dart
// Now shows loading spinner while initializing
if (!provider.isInitialized && provider.isLoading) {
  return const CircularProgressIndicator();
}
```

### Issue 2: Plan API Not Working ✅ FIXED
**Problem**: PlanComparisonDialog wasn't loading plans when opened.

**Solutions Applied**:
1. Changed dialog from StatelessWidget to StatefulWidget
2. Added automatic plan loading in `initState()`
3. Added retry button with error message display
4. Added debug logging to track API calls

### Issue 3: Usage History Not Visible ✅ FIXED
**Problem**: Usage history was only shown for paid users.

**Solution**: Changed condition to show for all authenticated users:
```dart
// Before: if (subscription.isPaidUser)
// After: Always show for authenticated users
_buildUsageHistoryCard(context, subscription, isDark)
```

## How to Test

### 1. Check Console Logs
Look for these debug messages in your console:

```
📋 Fetching subscription plans from: http://your-api/api/v1/subscriptions/plans
✅ Plans API response received: 200
📊 Loaded 3 subscription plans

👤 Fetching user subscription from: http://your-api/api/v1/subscriptions/me
✅ Subscription API response received: 200

📊 Fetching quota status from: http://your-api/api/v1/subscriptions/quotas
✅ Quotas API response received: 200
📊 Loaded 3 quota types
```

### 2. Check Quota Widgets on Generation Screens
**Where to look**: 
- SFX Generation Screen header (next to "SFX Assets" title)
- Music Generation Screen header (next to "Music Assets" title)
- Image Generation Screen header (next to "Image Assets" title)

**What you should see**:
- Loading spinner while initializing
- Colored badge showing "X/Y left" once loaded
- Colors: Green (good), Orange (low), Red (exceeded)

### 3. Check User Screen Subscription Hub
**Where to look**: User Screen (click on User icon in sidebar)

**What you should see**:
- **Current Plan Card**: Shows your active subscription tier
- **Early Access Activation Card**: (For free users only) Prominent card to enter discount code
- **Quota Overview Card**: All quota types with progress bars
- **Usage History Card**: Recent usage entries with "View All" button

### 4. Test Plan Comparison Dialog
**How to test**:
1. Go to User Screen
2. Click "View Plans" button in Early Access card
3. Dialog should open and automatically load plans

**What you should see**:
- Loading spinner initially
- 3 plan cards (Free, Starter, Pro) displayed horizontally
- Pricing with early access discount
- Quota details for each plan
- "I Have a Code" button at bottom

**If it fails**:
- Error message will display
- "Retry" button will appear
- Check console for error details

## Debugging Checklist

### If Quota Widget Still Not Showing:

1. **Check if SubscriptionProvider is initialized**
   ```dart
   // In any screen with Provider.of<SubscriptionProvider>
   print('Initialized: ${subscription.isInitialized}');
   print('Loading: ${subscription.isLoading}');
   print('Quotas count: ${subscription.quotas.length}');
   ```

2. **Check if user is authenticated**
   - Subscription only loads for authenticated users
   - Visitor mode won't trigger subscription loading

3. **Check API endpoint configuration**
   - Go to Settings Screen
   - Verify API Base URL is correct
   - Ensure Mock Mode is OFF

4. **Check console for initialization errors**
   - Look for "Error loading subscription", "Error loading quotas"
   - Check if 401/403 errors (authentication issue)

### If Plans Not Loading:

1. **Check API response format**
   - Backend should return: `{ "plans": [...] }`
   - Each plan should match `SubscriptionPlan` model structure

2. **Check authentication headers**
   - API client automatically adds Bearer token
   - Check if token is valid: Look at ApiClient logs

3. **Check endpoint path**
   - Should be: `GET /api/v1/subscriptions/plans`
   - Check if backend route is registered

4. **Test endpoint directly**
   ```bash
   curl -H "Authorization: Bearer YOUR_TOKEN" \
        http://localhost:8000/api/v1/subscriptions/plans
   ```

### If Usage History Not Showing:

1. **Check if section is visible**
   - Should appear below Quota Overview Card
   - Only for authenticated users (not visitors)

2. **Check if history is loading**
   - May show "No usage history yet" if empty
   - Check console for loading errors

3. **Click "View All" button**
   - Opens full dialog with filtering
   - Should make API call to `/subscriptions/usage-history`

## Common Backend Issues

### 1. CORS Errors
**Symptom**: Browser console shows CORS policy errors

**Solution**: Ensure backend has CORS configured:
```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Or specific origin
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### 2. Authentication Errors (401/403)
**Symptom**: Console shows "Authentication required" or "Access denied"

**Possible causes**:
- JWT token expired
- Token not being sent (check ApiClient)
- Backend JWT verification failing
- User not in database

**Check**:
```dart
// In ApiClient interceptor
print('Token: ${session?.accessToken}');
print('User ID: ${userId}');
```

### 3. Route Not Found (404)
**Symptom**: "The requested resource was not found"

**Check**:
- Backend router is included: `app.include_router(subscriptions.router)`
- Route path matches exactly: `/api/v1/subscriptions/plans`
- Backend is actually running

### 4. Data Format Errors
**Symptom**: "Failed to get available plans: type 'X' is not a subtype of type 'Y'"

**Solution**: Check backend response matches model:
```json
{
  "plans": [
    {
      "id": 1,
      "name": "Free",
      "display_name": "Free",
      "tier_level": 0,
      "original_price_monthly": 0.0,
      "features": {},
      "quota_config": {
        "sfx_generation": 5,
        "music_generation": 5
      },
      "is_active": true,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

## Expected API Calls on App Start

When a user logs in, you should see these API calls:

1. **GET /api/v1/subscriptions/me**
   - Gets current user subscription
   - Returns 200 with subscription data or 404 if none

2. **GET /api/v1/subscriptions/plans**
   - Gets all available plans
   - Returns 200 with plans array

3. **GET /api/v1/subscriptions/quotas**
   - Gets user's current quotas
   - Returns 200 with quotas array

If any of these fail, the UI will gracefully degrade:
- Quota widgets won't show (but app still works)
- Plan comparison will show error with retry
- Usage history will be empty

## Testing with Mock Mode

If backend isn't ready, you can test UI by creating a mock service:

```dart
// In subscription_service.dart - add mock mode support
class MockSubscriptionService implements SubscriptionService {
  @override
  Future<List<SubscriptionPlan>> getAvailablePlans() async {
    await Future.delayed(Duration(seconds: 1)); // Simulate network
    return [
      // Mock plan data
    ];
  }
  // ... implement other methods
}
```

## Quick Fixes

### Force Refresh Subscription Data
Add a refresh button in User Screen:
```dart
IconButton(
  icon: Icon(Icons.refresh),
  onPressed: () {
    final sub = Provider.of<SubscriptionProvider>(context, listen: false);
    sub.refresh();
  },
)
```

### Check Provider State
Add debug info to User Screen:
```dart
Text('Initialized: ${subscription.isInitialized}'),
Text('Loading: ${subscription.isLoading}'),
Text('Plans: ${subscription.availablePlans.length}'),
Text('Quotas: ${subscription.quotas.length}'),
if (subscription.errorMessage != null)
  Text('Error: ${subscription.errorMessage}', 
       style: TextStyle(color: Colors.red)),
```

### Bypass Quota Checks Temporarily
For testing generation without backend:
```dart
// In generation screen, comment out quota check
// checkQuota: () => subscriptionProvider.checkQuotaAvailable('sfx_generation'),
checkQuota: null, // Bypass quota check
```

## Need More Help?

Check these logs in order:

1. **Flutter Console**: Debug messages with 📋📊✅❌ prefixes
2. **Chrome DevTools Network Tab**: See actual HTTP requests
3. **Backend Logs**: Check if requests are reaching backend
4. **Database**: Verify subscription_plans table has data

The debug logging added will show exactly where the flow breaks!




