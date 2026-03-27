import 'package:arcane_forge/screens/game_design_assistant_v2/utils/chat_input_ui_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shows a visible loading state while switching to a selected session',
      () {
    final state = resolveChatInputUiState(
      canUseV2: true,
      isLoading: true,
      isLoadingSessionSelection: true,
      hasExpiredPendingSelection: false,
    );

    expect(state.enabled, isFalse);
    expect(state.hintText, 'Loading chat session...');
    expect(state.loadingLabel, 'Loading chat session...');
  });

  test('keeps the expired-selection hint when not loading', () {
    final state = resolveChatInputUiState(
      canUseV2: true,
      isLoading: false,
      isLoadingSessionSelection: false,
      hasExpiredPendingSelection: true,
    );

    expect(state.enabled, isTrue);
    expect(state.hintText, '旧选择已过期，直接输入即可继续');
    expect(state.loadingLabel, isNull);
  });
}
