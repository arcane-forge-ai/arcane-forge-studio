import 'package:flutter/material.dart';
import '../models/image_generation_models.dart';

enum ScreenType {
  dashboard,
  projectHome,
  knowledgeBase,
  gameDesignAssistant,
  knowledgeBaseQA,
  codeEditor,
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

  ScreenType get currentScreen => _currentScreen;
  ImageAsset? get preSelectedAsset => _preSelectedAsset;

  void changeScreen(ScreenType screenType, {ImageAsset? preSelectedAsset}) {
    _currentScreen = screenType;
    _preSelectedAsset = preSelectedAsset;
    notifyListeners();
  }
  
  void clearPreSelectedAsset() {
    _preSelectedAsset = null;
    // No need to notify listeners - clearing doesn't need to trigger rebuild
  }
}
