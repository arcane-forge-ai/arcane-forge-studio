# Asset Management API Requirements - FastAPI Backend Service

## Overview
This document outlines the requirements for a FastAPI backend service that provides comprehensive asset management capabilities for the Arcane Forge project. The service should be a superset of the current `ImageAssetService` interface, providing enhanced functionality for managing project assets, image generations, file storage, and metadata.

## Core Models

### ImageAsset
```python
class ImageAsset:
    id: str
    project_id: str
    name: str
    description: str
    created_at: datetime
    updated_at: datetime
    thumbnail: Optional[str]
    favorite_generation_id: Optional[str]
    tags: List[str] = []
    metadata: Dict[str, Any] = {}
    file_size: Optional[int]
    total_generations: int
```

### ImageGeneration
```python
class ImageGeneration:
    id: str
    asset_id: str
    image_path: str
    image_url: str  # Public URL for serving images
    parameters: Dict[str, Any]
    created_at: datetime
    status: GenerationStatus
    is_favorite: bool = False
    file_size: int
    dimensions: Dict[str, int]  # width, height
    format: str  # png, jpg, webp
    metadata: Dict[str, Any] = {}
```

### GenerationStatus
```python
class GenerationStatus(Enum):
    PENDING = "pending"
    GENERATING = "generating"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"
```

## API Endpoints

### Asset Management

#### GET `/api/v1/projects/{project_id}/assets`
**Description**: Retrieve all assets for a project with filtering and pagination
**Parameters**:
- `project_id` (path): Project identifier
- `limit` (query, optional): Number of assets to return (default: 50, max: 200)
- `offset` (query, optional): Number of assets to skip (default: 0)
- `search` (query, optional): Search term for name/description
- `tags` (query, optional): Comma-separated list of tags to filter by
- `has_generations` (query, optional): Filter by assets with/without generations
- `created_after` (query, optional): ISO datetime string
- `created_before` (query, optional): ISO datetime string
- `sort_by` (query, optional): `created_at`, `updated_at`, `name`, `generation_count` (default: `created_at`)
- `sort_order` (query, optional): `asc` or `desc` (default: `desc`)

**Response**:
```json
{
    "assets": [ImageAsset],
    "total": 150,
    "limit": 50,
    "offset": 0,
    "has_more": true
}
```

#### GET `/api/v1/assets/{asset_id}`
**Description**: Retrieve a specific asset with all its generations
**Parameters**:
- `asset_id` (path): Asset identifier
- `include_generations` (query, optional): Include generation details (default: true)

**Response**: `ImageAsset` with embedded generations

#### POST `/api/v1/projects/{project_id}/assets`
**Description**: Create a new asset
**Body**:
```json
{
    "name": "Main Character Portrait",
    "description": "Epic fantasy warrior character design",
    "tags": ["character", "fantasy", "warrior"],
    "metadata": {}
}
```
**Response**: Created `ImageAsset`

#### PUT `/api/v1/assets/{asset_id}`
**Description**: Update an existing asset
**Body**:
```json
{
    "name": "Updated Asset Name",
    "description": "Updated description",
    "tags": ["updated", "tags"],
    "metadata": {}
}
```
**Response**: Updated `ImageAsset`

#### DELETE `/api/v1/assets/{asset_id}`
**Description**: Delete an asset and all its generations
**Parameters**:
- `asset_id` (path): Asset identifier
- `force` (query, optional): Force deletion even if generations exist (default: false)

**Response**: `204 No Content`

### Generation Management

#### GET `/api/v1/assets/{asset_id}/generations`
**Description**: Retrieve all generations for an asset
**Parameters**:
- `asset_id` (path): Asset identifier
- `limit` (query, optional): Number of generations to return (default: 20)
- `offset` (query, optional): Number of generations to skip (default: 0)
- `status` (query, optional): Filter by generation status
- `is_favorite` (query, optional): Filter by favorite status

**Response**:
```json
{
    "generations": [ImageGeneration],
    "total": 25,
    "limit": 20,
    "offset": 0
}
```

#### GET `/api/v1/generations/{generation_id}`
**Description**: Retrieve a specific generation
**Response**: `ImageGeneration`

#### POST `/api/v1/assets/{asset_id}/generations`
**Description**: Create a new generation for an asset
**Body**:
```json
{
    "parameters": {
        "model": "Realistic_Vision_V5.1",
        "positive_prompt": "Epic fantasy artwork",
        "negative_prompt": "low quality",
        "width": 512,
        "height": 768,
        "steps": 30,
        "cfg_scale": 7.5,
        "seed": 123456
    },
    "status": "pending"
}
```
**Response**: Created `ImageGeneration`

#### PUT `/api/v1/generations/{generation_id}`
**Description**: Update a generation (status, favorite flag, metadata)
**Body**:
```json
{
    "status": "completed",
    "is_favorite": true,
    "image_path": "/path/to/generated/image.png",
    "metadata": {}
}
```
**Response**: Updated `ImageGeneration`

#### DELETE `/api/v1/generations/{generation_id}`
**Description**: Delete a specific generation
**Response**: `204 No Content`

#### POST `/api/v1/generations/{generation_id}/favorite`
**Description**: Mark a generation as favorite for its asset
**Response**: Updated `ImageGeneration`

#### DELETE `/api/v1/generations/{generation_id}/favorite`
**Description**: Remove favorite status from a generation
**Response**: Updated `ImageGeneration`

### File Management

#### POST `/api/v1/generations/{generation_id}/upload`
**Description**: Upload generated image file
**Body**: Multipart form data with image file
**Response**:
```json
{
    "image_path": "/path/to/uploaded/image.png",
    "image_url": "https://api.example.com/files/images/12345.png",
    "file_size": 2048576,
    "dimensions": {"width": 512, "height": 768},
    "format": "png"
}
```

#### GET `/api/v1/files/images/{image_id}`
**Description**: Serve image files with optional resizing
**Parameters**:
- `image_id` (path): Image identifier
- `width` (query, optional): Resize width
- `height` (query, optional): Resize height
- `quality` (query, optional): JPEG quality (1-100)
- `format` (query, optional): Output format (png, jpg, webp)

**Response**: Image file with appropriate headers

#### GET `/api/v1/assets/{asset_id}/thumbnail`
**Description**: Get asset thumbnail (favorite generation or first available)
**Parameters**:
- `asset_id` (path): Asset identifier
- `size` (query, optional): Thumbnail size (small, medium, large) (default: medium)

**Response**: Image file

### Bulk Operations

#### POST `/api/v1/projects/{project_id}/assets/bulk`
**Description**: Create multiple assets at once
**Body**:
```json
{
    "assets": [
        {
            "name": "Asset 1",
            "description": "Description 1",
            "tags": ["tag1"]
        },
        {
            "name": "Asset 2", 
            "description": "Description 2",
            "tags": ["tag2"]
        }
    ]
}
```
**Response**:
```json
{
    "created": [ImageAsset],
    "failed": []
}
```

#### DELETE `/api/v1/projects/{project_id}/assets/bulk`
**Description**: Delete multiple assets
**Body**:
```json
{
    "asset_ids": ["asset1", "asset2", "asset3"],
    "force": false
}
```
**Response**:
```json
{
    "deleted": ["asset1", "asset2"],
    "failed": [
        {
            "asset_id": "asset3",
            "error": "Asset has active generations"
        }
    ]
}
```

#### PUT `/api/v1/assets/bulk/tags`
**Description**: Update tags for multiple assets
**Body**:
```json
{
    "asset_ids": ["asset1", "asset2"],
    "operation": "add",  // "add", "remove", "replace"
    "tags": ["new_tag", "another_tag"]
}
```
**Response**: `200 OK` with count of updated assets

### Search and Discovery

#### GET `/api/v1/projects/{project_id}/assets/search`
**Description**: Advanced asset search with full-text search capabilities
**Parameters**:
- `q` (query): Search query
- `fields` (query, optional): Fields to search in (name, description, tags)
- `fuzzy` (query, optional): Enable fuzzy matching (default: false)
- `limit`, `offset`: Pagination parameters

**Response**: Paginated list of assets with relevance scores

#### GET `/api/v1/projects/{project_id}/tags`
**Description**: Get all tags used in project assets
**Response**:
```json
{
    "tags": [
        {
            "name": "character",
            "count": 15
        },
        {
            "name": "environment", 
            "count": 8
        }
    ]
}
```

### Statistics and Analytics

#### GET `/api/v1/projects/{project_id}/stats`
**Description**: Get project asset statistics
**Response**:
```json
{
    "total_assets": 150,
    "total_generations": 450,
    "generations_by_status": {
        "completed": 420,
        "failed": 20,
        "pending": 10
    },
    "storage_used": 2048576000,
    "most_used_tags": ["character", "environment", "item"],
    "generation_trends": {
        "daily": [/* last 30 days */],
        "models_used": {"Realistic_Vision_V5.1": 200, "DreamShaper_v7": 150}
    }
}
```

#### GET `/api/v1/assets/{asset_id}/stats`
**Description**: Get statistics for a specific asset
**Response**:
```json
{
    "total_generations": 15,
    "successful_generations": 13,
    "failed_generations": 2,
    "favorite_generation_id": "gen_123",
    "total_file_size": 45672000,
    "generation_history": [/* chronological list */]
}
```

## Database Schema Suggestions (Should consider along with existing schemas)

### Assets Table
- Indexed on: project_id, created_at, name
- Full-text search on: name, description
- JSON column for metadata and tags

### Generations Table  
- Indexed on: asset_id, created_at, status
- Foreign key constraints with CASCADE delete
- File path validation and cleanup triggers

### Files Table
- Separate table for file metadata
- Orphan file cleanup scheduled jobs
- Storage backend abstraction
