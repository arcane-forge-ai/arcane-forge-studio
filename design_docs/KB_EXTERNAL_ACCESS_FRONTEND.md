# Knowledge Base External Access - Frontend Guide

## Overview

Knowledge base file access now supports external vendor authentication using passcode, similar to the QA endpoint. When `qa_external_access_enabled` is true, vendors can access KB files using the same `qa_access_passcode`.

## Changed Endpoints

### 1. List Knowledge Base Files

**Endpoint:** `GET /api/v1/projects/{project_id}/files` or `GET /api/v1/projects/{project_id}/knowledge-base`

**Authentication:** Now supports both JWT and passcode authentication

**Headers:**
- **Internal users (project members):** `Authorization: Bearer <token>`
- **External vendors:** `X-QA-Passcode: <passcode>`

**Response:** Same as before - list of files with download URLs

**Example (External Vendor):**
```javascript
const response = await fetch(`/api/v1/projects/${projectId}/files`, {
  headers: {
    'X-QA-Passcode': 'vendor2026'
  }
});
const data = await response.json();
// data.files contains array of FileInfo objects with download_url
```

### 2. Get File Download URL

**Endpoint:** `GET /api/v1/projects/{project_id}/files/{file_id}/download`

**Authentication:** Now supports both JWT and passcode authentication

**Headers:**
- **Internal users (project members):** `Authorization: Bearer <token>`
- **External vendors:** `X-QA-Passcode: <passcode>`

**Response:** Same as before - signed download URL (expires in 1 hour)

**Example (External Vendor):**
```javascript
const response = await fetch(`/api/v1/projects/${projectId}/files/${fileId}/download`, {
  headers: {
    'X-QA-Passcode': 'vendor2026'
  }
});
const data = await response.json();
// data.download_url contains the signed URL
// data.expires_in shows expiration time (3600 seconds)
```

## What Stays the Same

The following endpoints **remain member-only** (no external access):
- ❌ `POST /api/v1/projects/{project_id}/files` - Upload file
- ❌ `POST /api/v1/projects/{project_id}/knowledge-base` - Create KB entry
- ❌ `PATCH /api/v1/projects/{project_id}/files/{file_id}` - Update file metadata
- ❌ `DELETE /api/v1/projects/{project_id}/files/{file_id}` - Delete file

External vendors have **read-only** access to list files and get download URLs only.

## Authentication Flow

1. **Check if external access is enabled** on the project:
   ```javascript
   // Project object now includes:
   {
     qa_external_access_enabled: true,  // Enables both QA and KB external access
     qa_access_passcode: "vendor2026"   // Shared passcode for QA and KB
   }
   ```

2. **Use the same passcode** for both QA and KB access:
   ```javascript
   // QA access
   fetch(`/api/v1/projects/${projectId}/qa`, {
     headers: { 'X-QA-Passcode': passcode }
   });
   
   // KB access (new)
   fetch(`/api/v1/projects/${projectId}/files`, {
     headers: { 'X-QA-Passcode': passcode }
   });
   ```

## Error Responses

- **401 Unauthorized:** Invalid passcode or no authentication provided
- **403 Forbidden:** JWT valid but user is not a project member
- **404 Not Found:** Project or file not found

## Implementation Notes

- Use the **same passcode** that's already used for QA external access
- No new project settings needed - reuses `qa_external_access_enabled` and `qa_access_passcode`
- All access is logged in the backend for audit purposes
- Download URLs expire after 1 hour (same as before)

## Migration Required

**None!** Existing internal user flows work exactly the same. This only adds external vendor access capability.
