class HumanHandoffDeliveryResultEntity {
  const HumanHandoffDeliveryResultEntity({
    required this.decision,
    required this.deliveryStatus,
    this.deliveryError,
  });

  final String decision;
  final String deliveryStatus;
  final String? deliveryError;

  bool get isSent => deliveryStatus.toLowerCase().trim() == 'sent';
  bool get isFailed => deliveryStatus.toLowerCase().trim() == 'failed';
}
