class ChatInputUiState {
  final bool enabled;
  final String hintText;
  final String? loadingLabel;

  const ChatInputUiState({
    required this.enabled,
    required this.hintText,
    this.loadingLabel,
  });
}

ChatInputUiState resolveChatInputUiState({
  required bool canUseV2,
  required bool isLoading,
  required bool isLoadingSessionSelection,
  required bool hasExpiredPendingSelection,
}) {
  if (!canUseV2) {
    return const ChatInputUiState(
      enabled: false,
      hintText: 'Sign in to use Game Design Assistant v2',
    );
  }

  if (isLoadingSessionSelection) {
    return const ChatInputUiState(
      enabled: false,
      hintText: 'Loading chat session...',
      loadingLabel: 'Loading chat session...',
    );
  }

  if (isLoading) {
    return const ChatInputUiState(
      enabled: false,
      hintText: 'Preparing chat...',
      loadingLabel: 'Preparing chat...',
    );
  }

  if (hasExpiredPendingSelection) {
    return const ChatInputUiState(
      enabled: true,
      hintText: '旧选择已过期，直接输入即可继续',
    );
  }

  return const ChatInputUiState(
    enabled: true,
    hintText: 'Ask about game design...',
  );
}
