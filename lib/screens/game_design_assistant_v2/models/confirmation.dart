class Confirmation {
  final String state;
  final String action;
  final String goal;
  final String reason;
  final String? preview;
  final String? targetPath;
  final String? sectionId;
  final String confirmText;
  final String cancelText;
  final String? transactionId;
  final String? argsChecksum;  // 可选（向后兼容）
  final String? permitId;      // 新增：可选
  final int? stepNumber;
  final int? totalSteps;       // 新增：总步骤数

  Confirmation({
    required this.state,
    required this.action,
    required this.goal,
    required this.reason,
    this.preview,
    this.targetPath,
    this.sectionId,
    required this.confirmText,
    required this.cancelText,
    this.transactionId,
    this.argsChecksum,
    this.permitId,
    this.stepNumber,
    this.totalSteps,
  });

  factory Confirmation.fromJson(Map<String, dynamic> json) {
    return Confirmation(
      state: json['state']?.toString() ?? 'pending',
      action: json['action']?.toString() ?? '',
      goal: json['goal']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      preview: json['preview']?.toString(),
      targetPath:
          json['targetPath']?.toString() ?? json['target_path']?.toString(),
      sectionId:
          json['sectionId']?.toString() ?? json['section_id']?.toString(),
      confirmText: json['confirmText']?.toString() ??
          json['confirm_text']?.toString() ??
          'Confirm',
      cancelText: json['cancelText']?.toString() ??
          json['cancel_text']?.toString() ??
          'Cancel',
      transactionId: json['transaction_id']?.toString(),
      argsChecksum: json['args_checksum']?.toString(),
      permitId: json['permit_id']?.toString(),
      stepNumber: json['step_number'] != null
          ? int.tryParse(json['step_number'].toString())
          : null,
      totalSteps: json['total_steps'] != null
          ? int.tryParse(json['total_steps'].toString())
          : null,
    );
  }
}
