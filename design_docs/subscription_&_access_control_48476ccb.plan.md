---
name: Subscription & Access Control
overview: Implement a complete subscription management system with tier-based access control, discount codes for early access, usage quota tracking and enforcement, and API middleware to protect AI endpoints.
todos:
  - id: db-schema
    content: "Create database migration with 5 new tables: subscription_plans, user_subscriptions, discount_codes, usage_quotas, usage_logs"
    status: completed
  - id: seed-data
    content: Add seed data for default plans (Free, Starter, Pro) in migration
    status: completed
  - id: models
    content: Create SQLAlchemy models for subscription system in backend/dependencies/datastores/models/subscriptions.py
    status: completed
  - id: subscription-service
    content: Implement subscription_service.py with plan management and activation logic
    status: completed
  - id: quota-service
    content: Implement quota_service.py with quota checking, consumption, and reset logic
    status: completed
  - id: discount-service
    content: Implement discount_code_service.py with code validation and redemption
    status: completed
  - id: api-models
    content: Add subscription-related Pydantic models to api/models/api_models.py
    status: completed
  - id: auth-middleware
    content: Create backend/dependencies/auth.py with quota and subscription checking dependencies
    status: completed
  - id: subscription-router
    content: Create api/routers/subscriptions.py with endpoints for plans, activation, and quota status
    status: completed
  - id: enforce-quotas
    content: Update AI endpoint routers (assets.py, sfx.py, music.py) to enforce quotas
    status: completed
  - id: user-trigger
    content: Update handle_new_user() database trigger to create default Free subscription
    status: completed
  - id: config
    content: Add SUBSCRIPTION_CONFIG to config.py with quota limits for each tier
    status: completed
  - id: error-handling
    content: Add structured error responses for quota exceeded and subscription required scenarios
    status: completed
  - id: testing
    content: Write unit and integration tests for subscription and quota flows
    status: completed
---

# User Subscription & Access Control System - Technical Implementation Plan

## Architecture Overview

The system uses **Supabase** (PostgreSQL + Auth), **SQLAlchemy ORM**, and **FastAPI**. Currently, authorization relies on Supabase Row Level Security (RLS) policies. This implementation will add application-level subscription and quota management while maintaining RLS for data isolation.

## Phase 1: Database Schema & Migrations

### 1.1 New Tables Required

Create migration: `supabase/migrations/20251210_create_subscription_system.sql`

**subscription_plans** - Define available plans (Free, Starter, Pro)

```sql
- id (SERIAL PRIMARY KEY)
- name (VARCHAR, e.g., "Free", "Starter", "Pro")
- display_name (VARCHAR)
- tier_level (INTEGER, 0=Free, 1=Starter, 2=Pro)
- original_price_monthly (DECIMAL)
- features (JSONB, flexible feature flags)
- quota_config (JSONB, contains daily/monthly limits)
- is_active (BOOLEAN)
- created_at, updated_at (TIMESTAMPTZ)
```

**user_subscriptions** - Track each user's current subscription

```sql
- id (SERIAL PRIMARY KEY)
- user_id (UUID, FK to users.id)
- plan_id (INTEGER, FK to subscription_plans.id)
- status (VARCHAR: 'active', 'suspended', 'expired')
- discount_code_used (VARCHAR, nullable, FK to discount_codes.code)
- actual_price_monthly (DECIMAL, after discount)
- subscribed_at (TIMESTAMPTZ)
- expires_at (TIMESTAMPTZ, nullable for free tier)
- auto_renew (BOOLEAN)
- created_at, updated_at (TIMESTAMPTZ)
- UNIQUE(user_id) - one active subscription per user
```

**discount_codes** - Early access and promotional codes

```sql
- id (SERIAL PRIMARY KEY)
- code (VARCHAR UNIQUE, e.g., "EARLYACCESS2025")
- plan_id (INTEGER, FK to subscription_plans.id)
- discount_type (VARCHAR: 'percentage', 'fixed', 'free')
- discount_value (DECIMAL)
- max_redemptions (INTEGER, nullable for unlimited)
- current_redemptions (INTEGER DEFAULT 0)
- valid_from (TIMESTAMPTZ)
- valid_until (TIMESTAMPTZ, nullable)
- is_active (BOOLEAN)
- metadata (JSONB, additional info)
- created_at, updated_at (TIMESTAMPTZ)
```

**usage_quotas** - Track usage across quota periods

```sql
- id (SERIAL PRIMARY KEY)
- user_id (UUID, FK to users.id)
- quota_type (VARCHAR: 'image_generation', 'sfx_generation', 'music_generation', 'chat_tokens')
- period_start (TIMESTAMPTZ)
- period_end (TIMESTAMPTZ)
- quota_limit (INTEGER, from plan config)
- usage_count (INTEGER DEFAULT 0)
- reset_frequency (VARCHAR: 'daily', 'monthly')
- created_at, updated_at (TIMESTAMPTZ)
- UNIQUE(user_id, quota_type, period_start) - one quota per type per period
- INDEX on (user_id, quota_type, period_end) for fast lookups
```

**usage_logs** - Audit trail for all AI operations

```sql
- id (BIGSERIAL PRIMARY KEY)
- user_id (UUID, FK to users.id)
- operation_type (VARCHAR: 'image_gen', 'sfx_gen', 'music_gen', 'chat')
- resource_id (VARCHAR, e.g., generation_id)
- units_consumed (INTEGER, 1 for generations, N for tokens)
- quota_type (VARCHAR)
- metadata (JSONB, request details)
- created_at (TIMESTAMPTZ)
- INDEX on (user_id, created_at)
- INDEX on (operation_type, created_at)
```

### 1.2 RLS Policies

Users can only view/modify their own subscriptions and quotas. Add policies similar to existing patterns in `20250703070453_create_game_design_assistant_tables.sql`.

### 1.3 Seed Data

Include default plans in migration:

- **Free Plan**: ID 1, tier 0, $0/month, 5 SFX/day, 5 Music/day, unlimited chat
- **Starter Plan**: ID 2, tier 1, $20/month ($10 early access), higher quotas
- **Pro Plan**: ID 3, tier 2, $60/month ($30 early access), highest quotas

## Phase 2: SQLAlchemy Models

Create `backend/dependencies/datastores/models/subscriptions.py`:

```python
from sqlalchemy import Column, Integer, String, DECIMAL, Boolean, DateTime, ForeignKey, Text, Index
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from backend.dependencies.datastores.postgre import Base
from datetime import datetime
```

Define 5 models matching the schema: `SubscriptionPlan`, `UserSubscription`, `DiscountCode`, `UsageQuota`, `UsageLog`.

Key relationships:

- `User.subscription` (one-to-one with `UserSubscription`)
- `UserSubscription.plan` (many-to-one with `SubscriptionPlan`)
- `UserSubscription.discount_code` (many-to-one with `DiscountCode`)

## Phase 3: Service Layer

### 3.1 Subscription Service

Create `backend/services/subscription_service.py`:

**Core Functions:**

- `get_user_subscription(db, user_id)` - Get current subscription
- `activate_subscription(db, user_id, discount_code)` - Activate with code. The discount_code record contains the plan_id, so the system automatically knows which plan (Starter/Pro) to activate based on the code.
- `get_plan_features(db, plan_id)` - Get plan configuration
- `check_feature_access(db, user_id, feature_name)` - Check if user can access feature
- `get_user_plan_info(db, user_id)` - Get detailed plan info for UI

### 3.2 Quota Service

Create `backend/services/quota_service.py`:

**Core Functions:**

- `check_quota_available(db, user_id, quota_type)` - Check if user has quota. Uses **lazy reset pattern**: automatically checks if period_end has passed and resets the quota before checking availability. This eliminates dependency on background jobs for quota resets.
- `consume_quota(db, user_id, quota_type, units=1)` - Decrement quota (also performs lazy reset check)
- `get_user_quotas(db, user_id)` - Get all quotas with remaining amounts
- `reset_expired_quotas()` - Optional background task for cleanup/optimization (not critical since lazy reset handles it)
- `initialize_quotas_for_user(db, user_id, plan_id)` - Setup quotas on subscription

**Lazy Reset Pattern:**

```python
# Pseudo-code for check_quota_available
def check_quota_available(db, user_id, quota_type):
    quota = get_quota_record(db, user_id, quota_type)
    
    # Auto-reset if period expired
    if quota.period_end < datetime.now():
        reset_quota_period(db, quota)
        quota.usage_count = 0
    
    return quota.usage_count < quota.quota_limit
```

### 3.3 Discount Code Service

Create `backend/services/discount_code_service.py`:

**Core Functions:**

- `validate_discount_code(db, code)` - Check if code is valid and available
- `redeem_discount_code(db, user_id, code)` - Apply code to user
- `create_discount_code(db, ...)` - Admin function to create codes
- `list_discount_codes(db, filters)` - Admin function

### 3.4 Usage Logging Service

Extend existing services or create `backend/services/usage_tracking_service.py`:

**Core Functions:**

- `log_usage(db, user_id, operation_type, resource_id, units, metadata)`
- `get_usage_history(db, user_id, filters)`
- `get_usage_analytics(db, user_id, time_range)` - For analytics dashboard

## Phase 4: API Models

Add to `api/models/api_models.py`:

```python
# Subscription Models
class SubscriptionPlanResponse(BaseModel)
class UserSubscriptionResponse(BaseModel)
class ActivateSubscriptionRequest(BaseModel)  # Contains discount_code
class ActivateSubscriptionResponse(BaseModel)
class QuotaStatusResponse(BaseModel)  # For each quota type
class UserQuotasResponse(BaseModel)  # All quotas
class UsageHistoryResponse(BaseModel)
```

## Phase 5: API Endpoints

### 5.1 Subscription Endpoints

Create `api/routers/subscriptions.py`:

```
GET    /api/v1/subscriptions/plans - List all plans
GET    /api/v1/subscriptions/me - Get current user subscription
POST   /api/v1/subscriptions/activate - Activate subscription with code
GET    /api/v1/subscriptions/quotas - Get user's quota status
GET    /api/v1/subscriptions/usage-history - Get usage logs
```

### 5.2 Admin Endpoints (optional for v1)

```
POST   /api/v1/admin/discount-codes - Create discount code
GET    /api/v1/admin/discount-codes - List codes
PATCH  /api/v1/admin/discount-codes/{code} - Update code
```

Include router in `api/main.py`:

```python
from api.routers import subscriptions
app.include_router(subscriptions.router, prefix="/api/v1/subscriptions", tags=["subscriptions"])
```

## Phase 6: Authorization Middleware

### 6.1 FastAPI Dependencies

Create `backend/dependencies/auth.py`:

```python
from fastapi import Depends, HTTPException, Header
from sqlalchemy.orm import Session

async def get_current_user_id(authorization: str = Header(None)) -> UUID:
    """Extract user_id from Supabase JWT token"""
    # Parse JWT, verify signature, extract user_id
    # For now, can accept user_id as header for testing
    pass

async def require_active_subscription(
    user_id: UUID = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """Dependency that ensures user has active paid subscription"""
    subscription = get_user_subscription(db, user_id)
    if subscription.plan.tier_level == 0:  # Free tier
        raise HTTPException(403, "This feature requires a paid subscription")
    return subscription

async def require_quota(
    quota_type: str,
    user_id: UUID = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """Dependency factory for quota checking"""
    if not check_quota_available(db, user_id, quota_type):
        raise HTTPException(429, f"Quota exceeded for {quota_type}")
    return user_id
```

### 6.2 Quota Enforcement on AI Endpoints

Update existing routers to add quota checks:

**In `api/routers/assets.py`** (Image generation):

```python
@router.post("/{project_id}/image-assets/{asset_id}/generate")
async def generate_image(
    user_id: UUID = Depends(require_quota("image_generation")),
    db=Depends(get_db)
):
    # Existing logic
    # After successful generation:
    consume_quota(db, user_id, "image_generation", 1)
    log_usage(db, user_id, "image_gen", generation_id, 1, metadata)
```

**In `api/routers/sfx.py`** (SFX generation):

```python
@router.post("/{project_id}/sfx-assets/{asset_id}/generate")
async def generate_sfx(
    user_id: UUID = Depends(require_quota("sfx_generation")),
    db=Depends(get_db)
):
    # Similar pattern
```

**In `api/routers/music.py`** (Music generation):

```python
@router.post("/{project_id}/music-assets/{asset_id}/generate")
async def generate_music(
    user_id: UUID = Depends(require_quota("music_generation")),
    db=Depends(get_db)
):
    # Similar pattern
```

**In `api/routers/chat.py`** (Chat - optional quota):

```python
# Free users: unlimited Game Design Assistant
# Paid users: higher limits (implement if needed)
```

## Phase 7: User Registration & Default Subscription

### 7.1 Update Supabase Trigger

**No changes needed to Flutter app!** The existing registration flow (Flutter → Supabase Auth) will continue to work. We only need to update the database trigger.

Modify the existing `handle_new_user()` function in the initial migration to also create a default subscription:

```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    free_plan_id INTEGER;
BEGIN
    -- Create user profile (existing logic)
    INSERT INTO public.users (id, username, created_at, updated_at)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
        NEW.created_at,
        NEW.updated_at
    );
    
    -- NEW: Get Free plan ID and create default subscription
    SELECT id INTO free_plan_id FROM subscription_plans WHERE name = 'Free' LIMIT 1;
    
    INSERT INTO public.user_subscriptions (user_id, plan_id, status, actual_price_monthly, subscribed_at)
    VALUES (NEW.id, free_plan_id, 'active', 0.00, NEW.created_at);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Registration Flow:**

```
Flutter app → Supabase Auth API (unchanged)
                    ↓
            auth.users row created
                    ↓
         Trigger automatically fires
                    ↓
     Creates public.users + user_subscriptions
                    ↓
        User has Free tier by default
```

## Phase 8: Error Handling & User Experience

### 8.1 Structured Error Responses

Define error schemas in `api/models/api_models.py`:

```python
class QuotaExceededError(BaseModel):
    error_type: str = "quota_exceeded"
    message: str
    quota_type: str
    reset_time: datetime
    upgrade_url: Optional[str]

class SubscriptionRequiredError(BaseModel):
    error_type: str = "subscription_required"
    message: str
    available_plans: List[SubscriptionPlanResponse]
```

Return these in HTTP 429 (quota) and 403 (subscription required) responses.

### 8.2 Quota Reset Job (Optional)

Create `backend/jobs/quota_reset.py` (optional cleanup job):

```python
def reset_expired_quotas():
    """Optional cleanup job to reset daily/monthly quotas in batch"""
    # This is NOT critical since lazy reset handles it on-demand
    # Can be used for optimization or cleanup of stale records
    # Run daily, check all quotas where period_end < now()
    # Reset usage_count to 0, update period dates
```

**Note:** With the lazy reset pattern implemented in `check_quota_available()`, this background job is optional and only serves as an optimization. The system will work correctly without it.

## Phase 9: Testing & Validation

### 9.1 Unit Tests

- Test subscription activation with valid/invalid codes
- Test quota checking and consumption
- Test quota reset logic
- Test enforcement on AI endpoints

### 9.2 Integration Tests

- Full flow: Register → Activate code → Generate asset → Check quota
- Test free tier limits
- Test paid tier limits

## Phase 10: Documentation

### 10.1 API Documentation

Update OpenAPI/Swagger docs with:

- New subscription endpoints
- Error responses (403, 429) on AI endpoints
- Quota status response schemas

### 10.2 Admin Guide

Create `docs/SUBSCRIPTION_ADMIN_GUIDE.md`:

- How to create discount codes
- How to manage plans
- How to monitor usage

## Key Files to Create/Modify

**New Files:**

- `supabase/migrations/20251210_create_subscription_system.sql`
- `backend/dependencies/datastores/models/subscriptions.py`
- `backend/services/subscription_service.py`
- `backend/services/quota_service.py`
- `backend/services/discount_code_service.py`
- `backend/dependencies/auth.py`
- `api/routers/subscriptions.py`

**Modified Files:**

- `api/models/api_models.py` - Add subscription models
- `api/main.py` - Include subscription router
- `api/routers/assets.py` - Add quota checks
- `api/routers/sfx.py` - Add quota checks
- `api/routers/music.py` - Add quota checks
- `supabase/migrations/20250703070453_create_game_design_assistant_tables.sql` - Update trigger (or create new migration to update it)
- `backend/dependencies/datastores/models/users.py` - Add subscription relationship

**Note:** No Flutter app changes required! User registration continues to work through Supabase Auth as-is.

## Configuration

Add to `config.py`:

```python
SUBSCRIPTION_CONFIG = {
    "free_tier_daily_quotas": {
        "sfx_generation": 5,
        "music_generation": 5,
        "image_generation": 0  # Not allowed on free tier
    },
    "starter_tier_monthly_quotas": {
        "sfx_generation": 500,
        "music_generation": 100,
        "image_generation": 200
    },
    "pro_tier_monthly_quotas": {
        "sfx_generation": 2000,
        "music_generation": 500,
        "image_generation": 1000
    }
}
```

## Success Metrics

- ✅ All AI endpoints protected by quota checks
- ✅ Free users cannot exceed daily limits
- ✅ Discount codes work for early access activation
- ✅ Clear error messages guide users to upgrade
- ✅ Usage is logged for future billing
- ✅ RLS policies prevent unauthorized data access
- ✅ System supports future expansion (BYOK, teams, etc.)

## Future Enhancements (Post-v1)

- Payment integration (Stripe/Paddle)
- Usage analytics dashboard
- Team/enterprise plans
- BYOK (Bring Your Own Key) option
- Email notifications for quota warnings
- Webhook for subscription events