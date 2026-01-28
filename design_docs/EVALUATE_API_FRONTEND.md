# Evaluate API - Frontend Integration Guide

## Overview
The Evaluate API provides game design knowledge base evaluation features. It analyzes a project's knowledge base and returns structured evaluation reports including gaps, risks, market analysis, and greenlight status.

**Important**: The evaluation runs **asynchronously**. The POST endpoint returns immediately with a pending evaluation, and you must poll the status to get results.

## Endpoints

### 1. Start New Evaluation
```
POST /api/{project_id}/evaluate
```

**Request Body** (optional):
```json
{
  "metadata_overrides": {
    "key": "value"
  }
}
```

**Response**: `EvaluateResponse` object with `status: "pending"` and an `id`

```json
{
  "id": 123,
  "project_id": 456,
  "status": "pending",
  "result": null,
  "error_message": null,
  "prompt_version": "v0.1",
  "model_identifier": "gpt-4",
  "created_at": "2026-01-27T10:30:00Z",
  "completed_at": null
}
```

**UI Suggestion**: 
- Primary action button: "Run Evaluation" or "Analyze Game Design"
- After POST returns, show loading state with "Evaluation in progress..."
- Start polling the evaluation status (see section below)
- Display success notification when `status` becomes `"completed"`
- Handle errors if `status` becomes `"failed"`

---

### 2. Get Evaluation History
```
GET /api/{project_id}/evaluate/history?limit=20&offset=0
```

**Query Parameters**:
- `limit` (1-100, default: 20) - Number of results per page
- `offset` (default: 0) - Pagination offset

**Response**:
```json
{
  "project_id": 123,
  "evaluations": [/* array of EvaluateResponse */]
}
```

**UI Suggestion**:
- Display as a table or timeline with:
  - Timestamp
  - Greenlight status (badge/indicator)
  - View details action
- Implement pagination controls
- Sort by most recent first

---

### 3. Get Latest Evaluation
```
GET /api/{project_id}/evaluate/latest
```

**Response**: `EvaluateResponse` object (404 if none exist)

**UI Suggestion**:
- Show as dashboard summary card
- Display key metrics: greenlight status, critical gaps, top risks
- "View Full Report" link to detailed view
- Handle 404 gracefully with "No evaluations yet" state

---

### 4. Get Specific Evaluation
```
GET /api/{project_id}/evaluate/{evaluation_id}
```

**Response**: `EvaluateResponse` object (404 if not found)

**Response Status Field**:
- `"pending"`: Evaluation has been queued but not started
- `"processing"`: Evaluation is currently running
- `"completed"`: Evaluation finished successfully, `result` field is populated
- `"failed"`: Evaluation failed, `error_message` field contains the error

**UI Suggestion**:
- Use this endpoint to **poll for status** after creating an evaluation
- While status is `"pending"` or `"processing"`, show loading indicator
- When status is `"completed"`, display detailed view:
  - Evaluation metadata (timestamp, ID)
  - Gaps analysis section
  - Risks assessment section
  - Market analysis section
  - Greenlight decision with reasoning
- If status is `"failed"`, show error message and retry option
- Export/print functionality

---

## Polling for Evaluation Results

After starting an evaluation with POST, you need to poll for completion:

**Recommended Polling Strategy**:
```javascript
async function waitForEvaluation(projectId, evaluationId) {
  const pollInterval = 3000; // Poll every 3 seconds
  const maxAttempts = 40; // Max 2 minutes (40 * 3s)
  
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const response = await fetch(`/api/${projectId}/evaluate/${evaluationId}`);
    const evaluation = await response.json();
    
    if (evaluation.status === 'completed') {
      return evaluation; // Success!
    } else if (evaluation.status === 'failed') {
      throw new Error(evaluation.error_message);
    }
    
    // Still pending or processing, wait and retry
    await new Promise(resolve => setTimeout(resolve, pollInterval));
  }
  
  throw new Error('Evaluation timeout');
}
```

**Alternative**: Use websockets or server-sent events if available for real-time updates.

---

## Visualization Recommendations

### Dashboard View
- **Hero Card**: Latest evaluation summary with greenlight status
- **Quick Action**: "Run New Evaluation" button
- **Recent History**: List of last 5 evaluations with timestamps

### Evaluation Detail Page
Organize content into collapsible sections:

1. **Overview**
   - Greenlight status (use color coding: green/yellow/red)
   - Evaluation date and ID
   - Overall score/rating if available

2. **Knowledge Gaps**
   - List of identified gaps
   - Severity indicators
   - Recommendations for each

3. **Risk Assessment**
   - Risk categories with severity levels
   - Mitigation suggestions

4. **Market Analysis**
   - Target audience insights
   - Competition analysis
   - Market opportunity summary

### Status Indicators
- ✅ **Greenlight**: Ready for production
- ⚠️ **Conditional**: Requires attention
- ❌ **Not Ready**: Critical issues found

---

## User Flow Example

```
1. User navigates to Project → Evaluation
2. Dashboard shows latest evaluation (if exists)
3. User clicks "Run New Evaluation"
4. POST request returns immediately with evaluation ID and status="pending"
5. UI shows loading indicator and starts polling
6. Poll GET /evaluate/{id} every 3 seconds
7. Status changes: pending → processing → completed (typically 30s-2min)
8. When completed: Show success notification and display results
9. User can navigate to history to compare past evaluations
```

### Handling Long-Running Evaluations

Since evaluations are async, consider these UX patterns:

1. **Progress Indicator**: Show "Analyzing knowledge base..." with spinner
2. **Background Processing**: Allow user to navigate away, show notification when complete
3. **Status Badge**: In history list, show status badges (pending/processing/completed/failed)
4. **Retry Failed**: If evaluation fails, provide a clear "Retry" button

---

## Error Handling

- **404**: No evaluations found → Show empty state with "Run first evaluation" CTA
- **400**: Invalid request (e.g., project not found) → Display error message to user
- **500**: Server error → Show retry option
- **Status "failed"**: Evaluation failed during processing → Display `error_message` and provide retry option
- **Timeout**: Polling exceeded max attempts → Show "Evaluation taking longer than expected, check history later"

---

## Data Models Reference

Refer to `api_models/evaluate.py` for complete type definitions:
- `EvaluateRequest`
- `EvaluateResponse`
- `EvaluateHistoryResponse`

