---
name: File Versioning UI with Grouping
overview: Add file versioning UI that groups files by filename, displays the newest version by default, and allows users to expand and view older versions.
todos:
  - id: create-version-group-model
    content: Create FileVersionGroup model class
    status: completed
  - id: add-grouping-logic
    content: Implement file grouping logic in _loadFiles()
    status: completed
  - id: update-state-management
    content: Add _fileGroups and _expandedGroups state variables
    status: completed
  - id: create-group-item-widget
    content: Create _buildFileGroupItem widget with expansion
    status: completed
  - id: update-file-item-widget
    content: Update _buildFileItem for version styling
    status: completed
  - id: test-versioning-ui
    content: Test grouping, expansion, and version display
    status: completed
---

# File Versioning UI with Grouping

## Overview

Implement a file versioning system in the Knowledge Base UI that groups files by name, shows the newest version by default, and allows users to expand to view version history. Rename functionality will be added later once backend support is ready.

## Implementation Plan

### 1. Create File Version Grouping Model

**New file**: `lib/screens/knowledge_base/models/file_version_group.dart`

Create a data structure to group files by filename:

- `String fileName` - the document name
- `List<KnowledgeBaseFile> versions` - all files with this name, sorted by date descending
- `KnowledgeBaseFile get latestVersion` - getter for most recent file
- `int get versionCount` - number of versions
- `bool hasMultipleVersions` - whether to show version controls

### 2. Update Knowledge Base Screen - File Grouping Logic

**File**: [`lib/screens/knowledge_base/knowledge_base_screen.dart`](lib/screens/knowledge_base/knowledge_base_screen.dart)

Modify the state to use grouped data:

- Change `List<KnowledgeBaseFile> _files` to `List<FileVersionGroup> _fileGroups`
- Add `Set<String> _expandedGroups` to track expansion state

Update `_loadFiles()` method (line 41):

- After fetching files from API, group them by `documentName`
- Sort versions within each group by `createdAt` descending (newest first)
- Create `FileVersionGroup` objects
- Store in `_fileGroups` list

Grouping logic:

```dart
List<FileVersionGroup> _groupFilesByName(List<KnowledgeBaseFile> files) {
  final grouped = <String, List<KnowledgeBaseFile>>{};
  
  for (final file in files) {
    grouped.putIfAbsent(file.documentName, () => []).add(file);
  }
  
  return grouped.entries.map((entry) {
    // Sort versions by date descending (newest first)
    final sortedVersions = entry.value..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return FileVersionGroup(
      fileName: entry.key,
      versions: sortedVersions,
    );
  }).toList();
}
```

### 3. Update Knowledge Base Screen - UI Components

**File**: [`lib/screens/knowledge_base/knowledge_base_screen.dart`](lib/screens/knowledge_base/knowledge_base_screen.dart)

Modify `_buildFilesList()` (line 303):

- Change ListView to iterate over `_fileGroups` instead of `_files`
- Call new `_buildFileGroupItem()` method

Create new `_buildFileGroupItem(FileVersionGroup group, int index)` widget:

- Display the latest version prominently
- If `group.hasMultipleVersions`: show version count badge (e.g., "3 versions ▼")
- Add expansion button/icon that toggles visibility
- When expanded, show all versions in an indented list
- Use `AnimatedSize` or similar for smooth expansion animation

Update `_buildFileItem(KnowledgeBaseFile file, {bool isLatest = true, bool isExpanded = false})`:

- Add optional parameters to style differently for latest vs. older versions
- Add version indicator badge:
  - Latest: Green "Latest" badge
  - Older: Gray badge with relative date (e.g., "2 days ago")
- If in expanded list (not latest), slightly indent and reduce opacity
- Keep existing view, download, and delete buttons
- Remove rename button (defer for later)

### 4. Update Delete Functionality

**File**: [`lib/screens/knowledge_base/knowledge_base_screen.dart`](lib/screens/knowledge_base/knowledge_base_screen.dart)

Modify `_deleteFile()` method (line 122):

- When a file is deleted, refresh the file list
- If deleting the last version of a filename, the entire group disappears
- If deleting one of multiple versions, just that version is removed from the group

### 5. UI Layout Details

**Collapsed State** (default for groups with multiple versions):

```
[Icon] Game_Design_Document.md          [MD]  2024-12-08  [👁][⬇][🗑]
       3 versions ▼
```

**Expanded State**:

```
[Icon] Game_Design_Document.md          [MD]  2024-12-08  [👁][⬇][🗑]
       3 versions ▲
       
       → [Icon] Game_Design_Document.md  [MD]  2024-12-06  [👁][⬇][🗑]
                                         (2 days ago)
       
       → [Icon] Game_Design_Document.md  [MD]  2024-12-01  [👁][⬇][🗑]
                                         (7 days ago)
```

**Visual Styling**:

- Latest version: Full opacity, bold filename, green "Latest" badge
- Older versions: 70% opacity, normal weight, gray date badge, slightly indented (8-16px)
- Version count badge: Small, blue background, rounded
- Expansion icon: Chevron down/up that rotates on toggle

### 6. Handle Edge Cases

- Single version files: No version badge, no expansion control, just display normally
- Empty state: Existing empty state UI remains unchanged
- Loading state: Existing loading indicator remains unchanged

## Technical Implementation Notes

### State Management

- `_expandedGroups` contains filenames of expanded groups
- Toggle expansion: `setState(() { _expandedGroups.contains(fileName) ? _expandedGroups.remove(fileName) : _expandedGroups.add(fileName) })`

### Performance

- File grouping happens once after API fetch, not on every rebuild
- Expansion state is UI-only, doesn't refetch data

### Compatibility

- Backend doesn't need changes - uses existing API
- Files with same name are already supported by backend
- Grouping is purely client-side logic

## Files to Create

1. `lib/screens/knowledge_base/models/file_version_group.dart` - Version grouping model

## Files to Modify

1. [`lib/screens/knowledge_base/knowledge_base_screen.dart`](lib/screens/knowledge_base/knowledge_base_screen.dart) - Main UI and grouping logic