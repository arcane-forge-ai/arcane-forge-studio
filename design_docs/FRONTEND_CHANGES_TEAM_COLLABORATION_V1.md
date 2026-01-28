# API Change Note: Team Collaboration v1

**Date:** 2026-01-16  
**Version:** 1.9.0  
**Status:** ✅ Implemented

## Overview

Team Collaboration v1 enables multi-user projects where:
- A project has **one owner** and **zero or more collaborators**
- **Members** (owner + collaborators) can view and work on shared assets, files, and chat sessions
- **Quota is always deducted from the acting user**, not the project owner
- **Only the chat session creator** can continue their own sessions (other members can view but not reply)

## New Endpoints

All endpoints require JWT authentication (`Authorization: Bearer <token>`).

### 1. Project Members

#### `GET /api/v1/projects/{project_id}/members`
List all members of a project (owner + collaborators).

**Auth:** Project member (owner or collaborator)

**Response:**
```json
{
  "project_id": 123,
  "members": [
    {
      "user_id": "uuid",
      "username": "string",
      "role": "owner" | "collaborator",
      "added_at": "2026-01-15T10:30:00Z"
    }
  ]
}
```

---

#### `POST /api/v1/projects/{project_id}/members`
Add a user as a collaborator to the project.

**Auth:** Project owner only

**Request:**
```json
{
  "user_id": "uuid"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Member added"
}
```

**Errors:**
- `403`: Not the project owner
- `404`: User or project not found
- `409`: User is already a member

---

#### `DELETE /api/v1/projects/{project_id}/members/{member_user_id}`
Remove a collaborator from the project.

**Auth:** Project owner only

**Notes:**
- Cannot remove the project owner
- Removing a member does not delete their created assets/chats (ownership is preserved)

**Response:**
```json
{
  "success": true,
  "message": "Member removed successfully"
}
```

**Errors:**
- `403`: Not the project owner or trying to remove owner
- `404`: Member not found

---

### 2. Invite Links

#### `POST /api/v1/projects/{project_id}/invites/link`
Create or retrieve an active invite link for the project.

**Auth:** Project owner only

**Notes:**
- If an active (non-revoked) link exists, returns it
- If none exists, creates a new one
- Invite links are **reusable** until revoked

**Request:** (empty body)

**Response:**
```json
{
  "project_id": 123,
  "token": "abc123..."
}
```

---

#### `POST /api/v1/projects/invites/link/redeem`
Redeem an invite link to join a project.

**Auth:** Any authenticated user

**Notes:**
- **Idempotent**: If user is already a member, returns success (no error)
- Token must be valid and not revoked

**Request:**
```json
{
  "token": "abc123..."
}
```

**Response:**
```json
{
  "project_id": 123
}
```

**Errors:**
- `404`: Invalid or revoked token
- `400`: Token format invalid

---

### 3. Email Invites

#### `POST /api/v1/projects/{project_id}/invites/email`
Invite a user by email address.

**Auth:** Project owner only

**Notes:**
- If the email is registered, the invite is linked to that user immediately
- If not registered, the invite is "pending" until that email signs up
- **Idempotent**: Re-inviting the same email updates the existing invite

**Request:**
```json
{
  "email": "collaborator@example.com"
}
```

**Response:**
```json
{
  "project_id": 123,
  "project_name": "My Game Project",
  "project_description": "Optional project description",
  "invited_email": "collaborator@example.com",
  "created_at": "2026-01-15T10:30:00Z",
  "accepted_at": "2026-01-15T10:35:00Z" | null
}
```

**Notes:**
- If `accepted_at` is `null`, the invite is pending
- If `accepted_at` is set, the invite was already accepted (user exists and was auto-added)

---

#### `GET /api/v1/projects/invites/email/pending`
List all pending email invites for the authenticated user.

**Auth:** Any authenticated user

**Notes:**
- Returns invites where `invited_email` matches the user's registered email and not yet accepted

**Response:**
```json
{
  "invites": [
    {
      "project_id": 123,
      "project_name": "My Game Project",
      "project_description": "Optional project description",
      "invited_email": "you@example.com",
      "created_at": "2026-01-15T10:30:00Z",
      "accepted_at": null
    }
  ]
}
```

---

#### `POST /api/v1/projects/invites/email/accept`
Accept an email invite to join a project.

**Auth:** Any authenticated user

**Notes:**
- User's email must match the `invited_email` in the invite
- **Idempotent**: If already a member, returns success

**Request:**
```json
{
  "project_id": 123
}
```

**Response:**
```json
{
  "success": true,
  "message": "Invite accepted"
}
```

**Errors:**
- `400`: Invite not found, email mismatch, or project not found
- `422`: Invalid request (e.g., missing or invalid `project_id`)

---

## Changed Behavior

### Access Control (All Project Resources)

All project-scoped endpoints now enforce **membership-based access**:

**Affected Endpoints:**
- `/api/v1/projects/{project_id}/*` (all project routes)
- `/api/v1/{project_id}/assets/**` (image assets)
- `/api/v1/{project_id}/sfx-assets/**` (SFX assets)
- `/api/v1/{project_id}/music-assets/**` (music assets)
- `/api/v1/projects/{project_id}/files/**` (knowledge base files)
- `/api/v1/projects/{project_id}/chat/**` (chat sessions)

**Previous Behavior:** Only project owner could access  
**New Behavior:** Project owner OR collaborators can access

**Response Codes:**
- `403 Forbidden`: User is not a member of the project
- `404 Not Found`: Project doesn't exist (error message unchanged for security)

---

### Quota Deduction (Breaking Change)

**Previous Behavior:**  
Quota was always deducted from the project owner when generating assets.

**New Behavior:**  
Quota is deducted from the **authenticated user performing the action**.

**Impact:**
- Collaborators use their own quota when generating images/audio
- Collaborators with insufficient quota will get `429 Too Many Requests`
- Project owner's quota is unaffected by collaborator actions

**Affected Endpoints:**
- `POST /api/v1/assets/{asset_id}/generations` (image generation)
- `POST /api/v1/sfx-assets/{asset_id}/generations` (SFX generation)
- `POST /api/v1/music-assets/{asset_id}/generations` (music generation)
- `POST /api/v1/workflows/{workflow_id}/execute` (workflow-based generation)

---

### Chat Session Ownership

**Previous Behavior:**  
Users could continue any chat session in a project.

**New Behavior:**  
- **View access**: All project members can view all chat sessions and messages
- **Continue restriction**: Only the session creator (`user_id` owner) can add messages to their session
- Attempting to continue another user's session returns `403 Forbidden`

**Affected Endpoints:**
- `POST /api/v1/chat` (when `session_id` is provided)

**Error Response:**
```json
{
  "detail": "Cannot continue another user's chat session"
}
```

---

## Asset Attribution

All newly created assets and generations now store `created_by_user_id` (the user who created them).

**New Fields in Responses:**
```json
{
  "id": "asset-123",
  "project_id": 456,
  "created_by_user_id": "uuid",
  "name": "My Asset",
  ...
}
```

**Models Affected:**
- Image assets + generations
- SFX assets + generations
- Music assets + generations

**Note:** Existing assets will have `created_by_user_id: null` until updated.

---

## Typical Workflows

### Workflow 1: Owner Invites Collaborator via Link

```
1. Owner: POST /projects/{id}/invites/link
   → Get invite link with token

2. Owner shares link with collaborator (out-of-band)

3. Collaborator: POST /projects/invites/link/redeem
   → Joins project as collaborator

4. Collaborator: GET /projects/{id}/assets
   → Can now view project assets
```

---

### Workflow 2: Owner Invites Collaborator via Email

```
1. Owner: POST /projects/{id}/invites/email
   { "email": "collab@example.com" }
   → Creates email invite

2. Collaborator: GET /projects/invites/email/pending
   → Sees pending invite

3. Collaborator: POST /projects/invites/email/accept
   { "project_id": 123 }
   → Joins project as collaborator
```

---

### Workflow 3: Collaborator Generates Image (Uses Own Quota)

```
1. Collaborator: POST /projects/{id}/assets
   → Creates asset (attributed to collaborator)

2. Collaborator: POST /assets/{asset_id}/generations
   { "prompt": "...", "model": "..." }
   → Generates image
   → Quota deducted from collaborator's account
   → Generation attributed to collaborator
```

---

## Migration Notes

### Database Changes

A new migration adds:
- `project_memberships` table
- `project_invite_links` table
- `project_email_invites` table
- `created_by_user_id` column to all asset/generation tables
- New RLS policies for member access

**Migration File:** `supabase/migrations/20260116120000_team_collaboration_v1.sql`

**Deployment:** Run the migration against your Supabase database before deploying the new API version.

---

### Dependencies

**New Python package required:**
```
email-validator==2.1.1
```

Update your `requirements.txt` and reinstall dependencies.

---

## Testing Recommendations

1. **Test membership access control:**
   - Verify collaborators can access project resources
   - Verify non-members get `403` errors

2. **Test quota isolation:**
   - Create a collaborator with low quota
   - Attempt generation → should consume collaborator's quota, not owner's

3. **Test chat ownership:**
   - User A creates a chat session
   - User B (collaborator) tries to continue it → should fail with `403`
   - User B creates their own session → should succeed

4. **Test invite flows:**
   - Test invite link redemption (idempotency)
   - Test email invite for existing vs. non-existing users
   - Test invite acceptance (idempotency)

---

## Questions or Issues?

Contact the backend team or check the PRD at `docs/design_docs/team_collab_prd.md`.

