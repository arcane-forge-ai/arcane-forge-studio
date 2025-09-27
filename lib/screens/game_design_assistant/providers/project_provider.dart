import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/project_model.dart';
import '../models/api_models.dart';

class ProjectProvider with ChangeNotifier {
  Project? _currentProject;
  List<ExtractedDocument> _extractedDocuments = [];
  
  // Mutation design data
  String? _pendingMutationMessage;
  String? _pendingMutationTitle;
  
  Project? get currentProject => _currentProject;
  List<ExtractedDocument> get extractedDocuments => _extractedDocuments;
  
  // Mutation design getters
  String? get pendingMutationMessage => _pendingMutationMessage;
  String? get pendingMutationTitle => _pendingMutationTitle;
  bool get hasPendingMutationDesign => _pendingMutationMessage != null;
  
  /// Load or create a default project
  Future<void> initializeProject() async {
    final prefs = await SharedPreferences.getInstance();
    final projectData = prefs.getString('current_project');
    
    if (projectData != null) {
      try {
        final Map<String, dynamic> json = jsonDecode(projectData);
        _currentProject = Project.fromJson(json);
      } catch (e) {
        // If loading fails, create a new project
        _currentProject = _createDefaultProject();
      }
    } else {
      _currentProject = _createDefaultProject();
    }
    
    // Load extracted documents
    await _loadExtractedDocuments();
    
    notifyListeners();
  }

  /// Initialize with a specific project ID and name
  Future<void> initializeWithProject(String projectId, String projectName) async {
    // Create a project instance with the provided ID and name
    _currentProject = Project(
      id: projectId,
      name: projectName,
      description: 'Project: $projectName',
      createdAt: DateTime.now(),
      hasKnowledgeBase: true, // Assume projects have knowledge base capability
    );
    
    // Load extracted documents for this project
    await _loadExtractedDocuments();
    
    notifyListeners();
  }
  
  /// Create a default project for demo purposes
  Project _createDefaultProject() {
    return Project(
      id: 'default_project',
      name: 'My Game Design Project',
      description: 'A collaborative game design project using AI assistance',
      createdAt: DateTime.now(),
      hasKnowledgeBase: false,
    );
  }
  
  /// Save current project to preferences
  Future<void> saveProject() async {
    if (_currentProject == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final projectJson = jsonEncode(_currentProject!.toJson());
    await prefs.setString('current_project', projectJson);
  }
  
  /// Update project details
  Future<void> updateProject({
    String? name,
    String? description,
    bool? hasKnowledgeBase,
  }) async {
    if (_currentProject == null) return;
    
    _currentProject = _currentProject!.copyWith(
      name: name,
      description: description,
      hasKnowledgeBase: hasKnowledgeBase,
    );
    
    await saveProject();
    notifyListeners();
  }
  
  /// Add extracted document
  void addExtractedDocument(ExtractedDocument document) {
    _extractedDocuments.add(document);
    _saveExtractedDocuments();
    notifyListeners();
  }
  
  /// Remove extracted document
  void removeExtractedDocument(String documentId) {
    _extractedDocuments.removeWhere((doc) => doc.id == documentId);
    _saveExtractedDocuments();
    notifyListeners();
  }
  
  /// Load extracted documents from preferences
  Future<void> _loadExtractedDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final documentsData = prefs.getString('extracted_documents');
    
    if (documentsData != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(documentsData);
        _extractedDocuments = jsonList
            .map((json) => ExtractedDocument.fromJson(json))
            .toList();
      } catch (e) {
        _extractedDocuments = [];
      }
    }
  }
  
  /// Save extracted documents to preferences
  Future<void> _saveExtractedDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _extractedDocuments.map((doc) => doc.toJson()).toList();
    await prefs.setString('extracted_documents', jsonEncode(jsonList));
  }
  
  /// Clear all extracted documents
  void clearExtractedDocuments() {
    _extractedDocuments.clear();
    _saveExtractedDocuments();
    notifyListeners();
  }
  
  /// Get knowledge base name for current project
  String? get knowledgeBaseName {
    if (_currentProject?.hasKnowledgeBase == true) {
      return _currentProject!.name.toLowerCase().replaceAll(' ', '_');
    }
    return null;
  }
  
  /// Set mutation design data
  void setMutationDesignData(String message, String title) {
    _pendingMutationMessage = message;
    _pendingMutationTitle = title;
    notifyListeners();
  }
  
  /// Clear mutation design data after it's been used
  void clearMutationDesignData() {
    _pendingMutationMessage = null;
    _pendingMutationTitle = null;
    notifyListeners();
  }
} 