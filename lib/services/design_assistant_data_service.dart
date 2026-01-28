/// Service for temporarily storing data to be sent to the Game Design Assistant
/// Used for auto-initiated conversations (e.g., mutation design, gap improvement)
class DesignAssistantDataService {
  static final DesignAssistantDataService _instance = DesignAssistantDataService._internal();
  factory DesignAssistantDataService() => _instance;
  DesignAssistantDataService._internal();

  String? _pendingMessage;
  String? _pendingTitle;

  // Getters
  String? get pendingMessage => _pendingMessage;
  String? get pendingTitle => _pendingTitle;
  bool get hasPendingData => _pendingMessage != null;

  // Set composed message data
  void setComposedMessageData(String message, String title) {
    _pendingMessage = message;
    _pendingTitle = title;
  }

  // Clear composed message data after it's been used
  void clearComposedMessageData() {
    _pendingMessage = null;
    _pendingTitle = null;
  }
}

