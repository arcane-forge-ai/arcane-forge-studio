# Project Knowledge Q&A API - Frontend Integration Guide

**Version:** v1.0  
**Date:** January 28, 2026  
**Status:** Ready for Integration

---

## Overview

The Project Knowledge Q&A feature provides a vendor-facing assistant that helps external partners find project information with:
- **Source-backed answers** from the knowledge base
- **Confidence signaling** (high/medium/low/unknown)
- **Smart escalation** to the right team member when information is missing
- **Unified knowledge base** supporting both documents and external links

---

## What's New

### 1. Unified Knowledge Base
- Knowledge base now supports **both documents and links**
- Each entry has:
  - **Entry Type**: document, link, folder, contact, other
  - **Visibility**: vendor_visible (default) or internal_only
  - **Authority Level**: source_of_truth, reference, or deprecated
  - **Tags**: Keywords for better search
  - **Description**: Summary/context

### 2. Responsibility Areas
- Define **who owns what** in your project
- Map topic keywords → team contacts
- External-facing display names (e.g., "UI Lead" instead of "alice@internal.com")
- Automatic escalation when Q&A can't find answers

### 3. Q&A Assistant
- Ask questions in natural language
- Get answers with source citations
- Automatic escalation to appropriate contacts
- Confidence levels indicate answer reliability

---

## API Endpoints

### Base URL
```
/api/v1/projects/{project_id}
```

### 1. Responsibility Areas Management

#### List Responsibility Areas
```http
GET /api/v1/projects/{project_id}/responsibility-areas
Authorization: Bearer {jwt_token}
```

**Response:**
```json
{
  "areas": [
    {
      "id": 1,
      "project_id": 123,
      "area_name": "UI Design",
      "area_keywords": ["ui", "interface", "button", "design", "ux"],
      "internal_contact": "alice@studio.com",
      "external_display_name": "UI Lead",
      "contact_method": "slack: #ui-questions",
      "notes": "Responsible for all UI/UX decisions",
      "created_at": "2026-01-28T10:00:00Z",
      "updated_at": "2026-01-28T10:00:00Z"
    }
  ]
}
```

#### Create Responsibility Area (Owner Only)
```http
POST /api/v1/projects/{project_id}/responsibility-areas
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "area_name": "Backend Engineering",
  "area_keywords": ["backend", "api", "server", "database"],
  "internal_contact": "bob@studio.com",
  "external_display_name": "Backend Lead",
  "contact_method": "email: backend@studio.com",
  "notes": "API and server infrastructure"
}
```

#### Update / Delete (similar pattern)
```http
PUT /api/v1/projects/{project_id}/responsibility-areas/{area_id}
DELETE /api/v1/projects/{project_id}/responsibility-areas/{area_id}
```

---

### 2. Knowledge Base Management

#### List Knowledge Base Entries
```http
GET /api/v1/projects/{project_id}/knowledge-base
Authorization: Bearer {jwt_token}
```

**Response:**
```json
{
  "files": [
    {
      "id": 1,
      "document_name": "Lead Developer",
      "file_type": "contact",
      "created_at": "2026-01-29T10:00:00Z",
      "entry_type": "contact",
      "visibility": "vendor_visible",
      "authority_level": "reference",
      "tags": ["developer", "john@studio.com"],
      "description": "Email: john@studio.com\nRole: Lead Developer\nContact Method: slack: #dev-team",
      "url": "mailto:john@studio.com"
    },
    {
      "id": 2,
      "document_name": "API Documentation",
      "file_type": "link",
      "entry_type": "link",
      "url": "https://docs.example.com/api",
      "description": "Complete API reference",
      "tags": ["api", "documentation"],
      "visibility": "vendor_visible",
      "authority_level": "source_of_truth"
    }
  ]
}
```

#### Create Knowledge Base Entry (Non-File)
```http
POST /api/v1/projects/{project_id}/knowledge-base
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "document_name": "Lead Developer",
  "entry_type": "contact",
  "description": "Main technical contact for API questions",
  "tags": ["developer", "technical"],
  "visibility": "vendor_visible",
  "authority_level": "reference",
  "contact_info": {
    "email": "john@studio.com",
    "role": "Lead Developer",
    "method": "slack: #dev-team"
  }
}
```

**Response:** Returns the created entry as a `FileInfo` object.

**Entry Types:**
- `contact` - Contact person (use `contact_info` field)
  - If `contact_info.email` is provided, the backend automatically creates a `mailto:` link in the `url` field
- `link` - External URL (use `url` field)
- `folder` - Folder/category grouping
- `other` - Other types of entries

**Example - Creating a Link:**
```json
{
  "document_name": "API Documentation",
  "entry_type": "link",
  "url": "https://docs.example.com/api",
  "description": "Complete API reference and examples",
  "tags": ["api", "documentation", "reference"],
  "visibility": "vendor_visible",
  "authority_level": "source_of_truth"
}
```

#### Update Knowledge Base Entry
```http
PATCH /api/v1/projects/{project_id}/knowledge-base/{entry_id}
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "document_name": "Senior Developer",
  "description": "Updated contact information",
  "tags": ["developer", "senior", "technical"],
  "visibility": "internal_only",
  "authority_level": "source_of_truth"
}
```

**Note:** All fields are optional. Only provided fields will be updated.

**Response:** Returns the updated entry as a `FileInfo` object.

#### Delete Knowledge Base Entry
```http
DELETE /api/v1/projects/{project_id}/knowledge-base/{entry_id}
Authorization: Bearer {jwt_token}
```

**Response:**
```json
{
  "success": true,
  "message": "Entry deleted successfully"
}
```

---

### 3. Q&A Assistant

#### Ask a Question
```http
POST /api/v1/projects/{project_id}/qa
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "question": "What are the UI button specifications?",
  "context": "Working on the main menu screen",
  "user_role": "vendor"
}
```

**Response (with answer):**
```json
{
  "answer": "The UI buttons should be 44x44 pixels...",
  "references": [
    {
      "type": "document",
      "title": "UI_Style_Guide.pdf",
      "url": null,
      "source": "Project Documentation"
    }
  ],
  "confidence": "high",
  "escalation": null,
  "needs_human_verification": false
}
```

**Response (with escalation):**
```json
{
  "answer": "Button color specifications are not documented.",
  "references": [],
  "confidence": "unknown",
  "escalation": {
    "contact_name": "UI Lead",
    "contact_method": "slack: #ui-questions",
    "area": "UI Design",
    "reason": "Color specs are managed by the UI team"
  },
  "needs_human_verification": true
}
```

---

### 4. External QA Access (No Authentication)

Project owners can enable external access to the QA endpoint by setting a passcode. This allows vendors and external partners to query the knowledge base without requiring a full user account.

#### Enable External Access

Update project settings to enable external access:

```http
PUT /api/v1/projects/{project_id}
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "qa_external_access_enabled": true,
  "qa_access_passcode": "vendor2026"
}
```

**Response:**
```json
{
  "id": 123,
  "name": "My Game Project",
  "qa_external_access_enabled": true,
  "qa_access_passcode": "vendor2026",
  ...
}
```

#### Query QA Externally (No Auth Required)

External users can access the QA endpoint using the passcode:

```http
POST /api/v1/projects/{project_id}/qa
X-QA-Passcode: vendor2026
Content-Type: application/json

{
  "question": "What are the UI button specifications?"
}
```

**Notes:**
- No `Authorization` header required
- External access automatically uses `user_role: "vendor"`
- Only sees `vendor_visible` content from knowledge base
- All access is logged with IP address for audit trail

**Response (same as authenticated):**
```json
{
  "answer": "The UI buttons should be 44x44 pixels...",
  "references": [...],
  "confidence": "high",
  "escalation": null,
  "needs_human_verification": false
}
```

#### Disable External Access

```http
PUT /api/v1/projects/{project_id}
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "qa_external_access_enabled": false,
  "qa_access_passcode": null
}
```

#### Security Considerations

- **Passcode Storage**: Stored as plaintext for easy sharing. Use strong, unique passcodes.
- **Access Logging**: All external access is logged with IP address, timestamp, and question preview.
- **Rate Limiting**: Consider implementing rate limiting on frontend to prevent abuse.
- **Visibility**: External users can only see `vendor_visible` content, never `internal_only`.

---

## TypeScript Models

```typescript
// Q&A Models
interface QARequest {
  question: string;           // Required, 1-2000 chars
  context?: string;           // Optional, up to 1000 chars
  user_role?: "vendor" | "internal"; // Default: "vendor"
}

interface QAResponse {
  answer: string;
  references: QAReference[];
  confidence: "high" | "medium" | "low" | "unknown";
  escalation?: QAEscalation;
  needs_human_verification: boolean;
}

interface QAReference {
  type: "document" | "link" | "folder" | "contact" | "responsibility_area";
  title: string;
  url?: string;
  source?: string;
  excerpt?: string;
}

interface QAEscalation {
  contact_name: string;      // External display name
  contact_method?: string;
  area?: string;
  reason: string;
}

// Responsibility Areas
interface ResponsibilityArea {
  id: number;
  project_id: number;
  area_name: string;
  area_keywords: string[];
  internal_contact: string;
  external_display_name: string;
  contact_method?: string;
  notes?: string;
  created_at: string;
  updated_at: string;
}

// Knowledge Base Models
type EntryType = "document" | "link" | "folder" | "contact" | "other";
type Visibility = "vendor_visible" | "internal_only";
type AuthorityLevel = "source_of_truth" | "reference" | "deprecated";

interface ContactInfo {
  email?: string;
  phone?: string;
  role?: string;
  method?: string;  // e.g., "slack: #channel", "email: user@example.com"
}

interface KnowledgeBaseEntry {
  id: number;
  document_name: string;
  file_type: string;
  created_at: string;
  entry_type: EntryType;
  url?: string;
  description?: string;
  tags?: string[];
  visibility: Visibility;
  authority_level: AuthorityLevel;
  // Additional fields for documents
  document_ids?: string[];
  storage_file_key?: string;
  download_url?: string;
  has_storage: boolean;
}

interface KnowledgeBaseEntryCreateRequest {
  document_name: string;      // Required, max 255 chars
  entry_type: EntryType;      // Required
  description?: string;
  tags?: string[];
  visibility?: Visibility;    // Default: "vendor_visible"
  authority_level?: AuthorityLevel;  // Default: "reference"
  url?: string;              // For link entries
  contact_info?: ContactInfo; // For contact entries
}

interface KnowledgeBaseEntryUpdateRequest {
  document_name?: string;
  description?: string;
  url?: string;
  tags?: string[];
  visibility?: Visibility;
  authority_level?: AuthorityLevel;
}
```

---

## Usage Examples

### Creating Knowledge Base Entries

#### Create a Contact Entry
```typescript
async function addContactEntry(projectId: number, token: string) {
  const contact = {
    document_name: "Lead Developer",
    entry_type: "contact",
    description: "Main technical contact for API questions",
    tags: ["developer", "technical", "api"],
    visibility: "vendor_visible",
    authority_level: "reference",
    contact_info: {
      email: "john@studio.com",
      role: "Lead Developer",
      method: "slack: #dev-team"
    }
    // Note: Backend automatically creates mailto: link from email
    // The returned entry will have url: "mailto:john@studio.com"
  };
  
  const response = await fetch(`/api/v1/projects/${projectId}/knowledge-base`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(contact)
  });
  
  return await response.json();
}
```

#### Create a Link Entry
```typescript
async function addLinkEntry(projectId: number, token: string) {
  const link = {
    document_name: "API Documentation",
    entry_type: "link",
    url: "https://docs.example.com/api",
    description: "Complete API reference and examples",
    tags: ["api", "documentation", "reference"],
    visibility: "vendor_visible",
    authority_level: "source_of_truth"
  };
  
  const response = await fetch(`/api/v1/projects/${projectId}/knowledge-base`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(link)
  });
  
  return await response.json();
}
```

#### Update an Entry
```typescript
async function updateEntry(projectId: number, entryId: number, token: string) {
  const updates = {
    description: "Updated description with more details",
    tags: ["updated", "new-tag"],
    authority_level: "source_of_truth"
  };
  
  const response = await fetch(
    `/api/v1/projects/${projectId}/knowledge-base/${entryId}`,
    {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(updates)
    }
  );
  
  return await response.json();
}
```

### Setting Up Responsibility Areas

```typescript
const areas = [
  {
    area_name: "UI/UX Design",
    area_keywords: ["ui", "ux", "interface", "design", "button"],
    internal_contact: "alice@internal.com",
    external_display_name: "UI Lead",
    contact_method: "slack: #ui-questions"
  }
];

for (const area of areas) {
  await fetch(`/api/v1/projects/${projectId}/responsibility-areas`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(area)
  });
}
```

### Q&A Chat Interface

```typescript
async function askQuestion(projectId: number, question: string) {
  const response = await fetch(`/api/v1/projects/${projectId}/qa`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ question, user_role: 'vendor' })
  });
  
  const data: QAResponse = await response.json();
  
  // Display answer
  displayAnswer(data.answer);
  
  // Show confidence indicator
  displayConfidence(data.confidence);
  
  // Show references
  if (data.references.length > 0) {
    displayReferences(data.references);
  }
  
  // Handle escalation
  if (data.escalation) {
    showEscalationBanner(
      `Contact ${data.escalation.contact_name} for help`,
      data.escalation.contact_method
    );
  }
  
  return data;
}
```

### Confidence Badge Component

```typescript
function getConfidenceBadge(confidence: string) {
  const badges = {
    high: { color: 'green', text: 'High Confidence', icon: '✓' },
    medium: { color: 'yellow', text: 'Medium Confidence', icon: '~' },
    low: { color: 'orange', text: 'Low Confidence', icon: '?' },
    unknown: { color: 'gray', text: 'Unverified', icon: '!' }
  };
  
  return badges[confidence] || badges.unknown;
}
```

---

## UI/UX Recommendations

### Confidence Levels
```
High     → Green badge, "Verified from authoritative sources"
Medium   → Yellow badge, "Found in draft/reference docs"
Low      → Orange badge, "Limited information - verify with team"
Unknown  → Gray badge, "Not documented - contact team"
```

### Escalation Flow
```
[Answer not found]
↓
Display: "This information isn't documented yet."
↓
Show contact card:
  📧 Contact: UI Lead
  💬 Method: slack: #ui-questions
↓
[Button: "Ask UI Lead"]
```

### References Display
- Show up to 3-5 references per answer
- Indicate authority level (source of truth vs reference)
- Make links clickable
- Show document excerpts when available

---

## Best Practices

### For Project Owners
1. Set up 3-5 key responsibility areas early
2. Use broad, searchable keywords
3. Keep external display names professional
4. Tag knowledge base entries appropriately
5. **Use strong passcodes** (12+ characters, mix of letters/numbers)
6. **Rotate passcodes** periodically for security
7. **Monitor access logs** to detect unusual patterns

### For Frontend Developers
1. Handle all confidence levels (don't hide low confidence)
2. Show loading state (Q&A can take 5-10 seconds)
3. Cache responsibility areas (rarely change)
4. Preserve escalation context clearly
5. **Include passcode in header** for external access: `X-QA-Passcode: {passcode}`
6. **Show "External Access" badge** to indicate authentication mode
7. **Store passcode securely** in session/local storage, not in URL

---

## Migration Notes

- All existing KB entries get default values (backward compatible)
- New endpoints only - existing APIs unchanged
- No database migration needed for frontend

---

## Testing Checklist

### Knowledge Base Management
- [ ] Can list all KB entries (documents, links, contacts)
- [ ] Can create contact entries with contact_info
- [ ] Can create link entries with URL
- [ ] Can create folder/other entry types
- [ ] Can update entry metadata (description, tags, visibility)
- [ ] Can delete entries
- [ ] Entry visibility is enforced (vendor vs internal)
- [ ] Authority levels are properly stored

### Responsibility Areas
- [ ] Can create responsibility areas as owner
- [ ] Can list areas as member
- [ ] Area keywords work for escalation matching

### Q&A Features
- [ ] Q&A returns answers with references
- [ ] Q&A includes links and contacts in references
- [ ] Q&A escalates when info not found
- [ ] Confidence levels display correctly
- [ ] Vendor role filters internal_only entries
- [ ] Loading states work (5-10s)
- [ ] Escalation shows external display name

### External Access Features
- [ ] Can enable external access and set passcode
- [ ] External users can access with valid passcode
- [ ] Invalid passcode is rejected with 401
- [ ] Disabled external access rejects passcode
- [ ] JWT authentication still works when external enabled
- [ ] External access only sees vendor_visible content
- [ ] Access logs show external vs internal differentiation
- [ ] IP addresses are logged correctly

---

## Changelog

### v1.2 (2026-01-29)
- ✨ New: Knowledge Base CRUD API endpoints
- ✨ New: Create non-file entries (contacts, links, folders) via API
- ✨ New: Update KB entry metadata (PATCH endpoint)
- ✨ New: ContactInfo model for structured contact information
- 📝 Docs: Complete KB management documentation with TypeScript models
- 🔄 Change: KB endpoints support both `/knowledge-base` and `/files` paths

### v1.1 (2026-01-29)
- ✨ New: External QA access with passcode authentication
- ✨ New: QA access audit logging (tracks IP, success/failure, response time)
- 🔒 Security: All QA access logged with IP address for audit trail
- 📊 Analytics: Access logs table supports future analytics dashboards

### v1.0 (2026-01-28)
- ✨ New: Project Knowledge Q&A API
- ✨ New: Responsibility Areas management
- ✨ New: Unified knowledge base (documents + links)
- ✨ New: Confidence signaling and smart escalation
