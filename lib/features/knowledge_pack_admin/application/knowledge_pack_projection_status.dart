import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

const Set<String> knowledgeProjectionActiveStatuses = <String>{
  'queued',
  'processing',
};

const Set<String> knowledgeProjectionTerminalStatuses = <String>{
  'ready',
  'failed',
  'cancelled',
};

String knowledgeProjectionStateLabel(AcpRow? projection) {
  if (projection == null) {
    return 'Relational only';
  }
  final status = _text(projection['Status']).toLowerCase();
  final operation = _text(projection['Operation']).toLowerCase();
  return switch (status) {
    'queued' => 'Queued',
    'processing' when operation == 'reindex' => 'Reindexing',
    'processing' => 'Indexing',
    'ready' when projection['IsCurrentReady'] == true => 'Searchable',
    'ready' => 'Stale provider configuration',
    'failed' => 'Failed',
    'cancelled' => 'Cancelled',
    _ => status.isEmpty ? 'Relational only' : status,
  };
}

String knowledgeProjectionTargetLabel(AcpRow? projection) {
  if (projection == null) {
    return '';
  }
  final provider = _text(projection['Provider']);
  final fingerprint = _text(projection['TargetFingerprint']);
  final shortFingerprint = fingerprint.length <= 12
      ? fingerprint
      : fingerprint.substring(0, 12);
  if (provider.isEmpty) {
    return shortFingerprint;
  }
  return shortFingerprint.isEmpty ? provider : '$provider · $shortFingerprint';
}

String knowledgeProjectionMatchLabel(AcpRow? projection) {
  if (projection == null) {
    return 'No';
  }
  final status = _text(projection['Status']).toLowerCase();
  if (knowledgeProjectionActiveStatuses.contains(status)) {
    return 'Pending';
  }
  return projection['IsCurrentReady'] == true ? 'Yes' : 'No';
}

String knowledgeProjectionLastEvent(AcpRow? projection) {
  if (projection == null) {
    return '';
  }
  for (final key in const <String>[
    'CompletedAt',
    'FailedAt',
    'StartedAt',
    'RequestedAt',
  ]) {
    final value = _text(projection[key]);
    if (value.isNotEmpty) {
      return value;
    }
  }
  return '';
}

String sanitizeKnowledgeProjectionFailure(Object? value, {int limit = 240}) {
  var detail = _text(value).replaceAll(RegExp(r'\s+'), ' ');
  if (detail.isEmpty) {
    return '';
  }
  detail = detail
      .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '[endpoint]')
      .replaceAll(
        RegExp(
          r'\b(password|passwd|secret|token|api[_-]?key|authorization)\s*[:=]\s*[^\s,;]+',
          caseSensitive: false,
        ),
        '[credential redacted]',
      )
      .replaceAll(
        RegExp(r'(?:[A-Za-z]:\\|/(?:home|Users|var|etc|opt|srv|tmp)/)\S+'),
        '[path]',
      );
  if (detail.length <= limit) {
    return detail;
  }
  return '${detail.substring(0, limit - 1).trimRight()}…';
}

String knowledgePackVersionLabel(AcpRow projection) {
  final navigation = projection['KnowledgePackVersion'];
  if (navigation is Map) {
    final number = _text(navigation['VersionNumber']);
    if (number.isNotEmpty) {
      return 'v$number';
    }
  }
  final id = _text(projection['KnowledgePackVersionId']);
  return id.length <= 12 ? id : id.substring(0, 12);
}

bool knowledgeProjectionIsActive(AcpRow projection) =>
    knowledgeProjectionActiveStatuses.contains(
      _text(projection['Status']).toLowerCase(),
    );

bool knowledgeProjectionIsTerminal(AcpRow projection) =>
    knowledgeProjectionTerminalStatuses.contains(
      _text(projection['Status']).toLowerCase(),
    );

String _text(Object? value) => value?.toString().trim() ?? '';
