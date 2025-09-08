import 'package:flutter/material.dart';

enum ScreenType {
  dashboard,
  projectHome,
  knowledgeBase,
  gameDesignAssistant,
  codeEditor,
  imageGenerator,
  imageGenerationOverview,
  imageGenerationGeneration,
  soundGenerator,
  sfxGenerationOverview,
  sfxGenerationGeneration,
  musicGenerator,
  webServer,
  versions,
  stats,
  feedbacks,
  // Main dashboard screens
  projects,
  settings,
  user,
}

class MenuAppController extends ChangeNotifier {
  ScreenType _currentScreen = ScreenType.dashboard;

  ScreenType get currentScreen => _currentScreen;

  void changeScreen(ScreenType screenType) {
    _currentScreen = screenType;
    notifyListeners();
  }
}
