import 'package:mugen_ui/shared/application/pagination.dart';

class HumanHandoffSessionListQuery {
  const HumanHandoffSessionListQuery({
    required this.tenantId,
    required this.pageRequest,
    this.status = 'active',
    this.platform,
    this.serviceRouteKey,
    this.ownerUserId,
  });

  final String tenantId;
  final PageRequest pageRequest;
  final String? status;
  final String? platform;
  final String? serviceRouteKey;
  final String? ownerUserId;
}

class HumanHandoffTranscriptQuery {
  const HumanHandoffTranscriptQuery({
    required this.tenantId,
    required this.sessionId,
    this.limit = 80,
  });

  final String tenantId;
  final String sessionId;
  final int limit;
}

class HumanHandoffReplyInput {
  const HumanHandoffReplyInput({
    required this.tenantId,
    required this.sessionId,
    required this.content,
    required this.messageId,
    this.traceId,
    this.operatorDisplayName,
  });

  final String tenantId;
  final String sessionId;
  final String content;
  final String messageId;
  final String? traceId;
  final String? operatorDisplayName;
}

class HumanHandoffDeactivateInput {
  const HumanHandoffDeactivateInput({
    required this.tenantId,
    required this.sessionId,
    this.reason,
  });

  final String tenantId;
  final String sessionId;
  final String? reason;
}
