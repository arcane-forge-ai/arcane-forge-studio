class Confirmation {
  final String state;
  final String action;
  final String goal;
  final String reason;
  final String? preview;
  final String confirmText;
  final String cancelText;
  final String? transactionId;

  Confirmation({
    required this.state,
    required this.action,
    required this.goal,
    required this.reason,
    this.preview,
    required this.confirmText,
    required this.cancelText,
    this.transactionId,
  });

  factory Confirmation.fromJson(Map<String, dynamic> json) {
    return Confirmation(
      state: json['state']?.toString() ?? 'pending',
      action: json['action']?.toString() ?? '',
      goal: json['goal']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      preview: json['preview']?.toString(),
      confirmText: json['confirmText']?.toString() ??
          json['confirm_text']?.toString() ??
          'Confirm',
      cancelText: json['cancelText']?.toString() ??
          json['cancel_text']?.toString() ??
          'Cancel',
      transactionId: json['transaction_id']?.toString(),
    );
  }
}
