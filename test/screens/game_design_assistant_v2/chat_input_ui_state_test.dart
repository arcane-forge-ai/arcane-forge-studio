import 'package:arcane_forge/screens/game_design_assistant_v2/utils/chat_input_ui_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the input quiet while a selected session is loading', () {
    final state = resolveChatInputUiState(
      canUseV2: true,
      isLoading: true,
      isLoadingSessionSelection: true,
      hasExpiredPendingSelection: false,
    );

    expect(state.enabled, isFalse);
    expect(state.hintText, 'Ask about game design...');
    expect(state.loadingLabel, isNull);
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
