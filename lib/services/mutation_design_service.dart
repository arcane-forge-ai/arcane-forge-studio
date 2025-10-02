class MutationDesignService {
  static final MutationDesignService _instance = MutationDesignService._internal();
  factory MutationDesignService() => _instance;
  MutationDesignService._internal();

  String? _pendingMessage;
  String? _pendingTitle;

  // Getters
  String? get pendingMessage => _pendingMessage;
  String? get pendingTitle => _pendingTitle;
  bool get hasPendingMutationDesign => _pendingMessage != null;

  // Set mutation design data
  void setMutationDesignData(String message, String title) {
    _pendingMessage = message;
    _pendingTitle = title;
  }

  // Clear mutation design data after it's been used
  void clearMutationDesignData() {
    _pendingMessage = null;
    _pendingTitle = null;
  }
} 