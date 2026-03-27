import 'package:flutter/material.dart';
import '../models/image_generation_models.dart';

enum ScreenType {
  dashboard,
  projectHome,
  knowledgeBase,
  gameDesignAssistant,
  gameDesignAssistantV2,
  knowledgeBaseQA,
  codingAgent,
  developerToolkit,
  imageGenerator,
  imageGenerationOverview,
  imageGenerationGeneration,
  soundGenerator,
  sfxGenerationOverview,
  sfxGenerationGeneration,
  musicGenerator,
  musicGenerationOverview,
  musicGenerationGeneration,
  webServer,
  versions,
  stats,
  feedbacks,
  evaluate,
  // Main dashboard screens
  projects,
  invites,
  settings,
  user,
}

class MenuAppController extends ChangeNotifier {
  ScreenType _currentScreen = ScreenType.dashboard;
  ImageAsset? _preSelectedAsset;
  bool _isDesktopSidebarCollapsed = false;

  ScreenType get currentScreen => _currentScreen;
  ImageAsset? get preSelectedAsset => _preSelectedAsset;
  bool get isDesktopSidebarCollapsed => _isDesktopSidebarCollapsed;

  void changeScreen(ScreenType screenType, {ImageAsset? preSelectedAsset}) {
    _currentScreen = screenType;
    _preSelectedAsset = preSelectedAsset;
    notifyListeners();
  }

  void clearPreSelectedAsset() {
    _preSelectedAsset = null;
    // No need to notify listeners - clearing doesn't need to trigger rebuild
  }

  void toggleDesktopSidebar() {
    _isDesktopSidebarCollapsed = !_isDesktopSidebarCollapsed;
    notifyListeners();
  }

  void setDesktopSidebarCollapsed(bool collapsed) {
    if (_isDesktopSidebarCollapsed == collapsed) {
      return;
    }
    _isDesktopSidebarCollapsed = collapsed;
    notifyListeners();
  }

  void expandDesktopSidebar() {
    setDesktopSidebarCollapsed(false);
  }
}
