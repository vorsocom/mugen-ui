import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/application/knowledge_pack_projection_status.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

void main() {
  test('projection lifecycle labels distinguish every searchability state', () {
    expect(knowledgeProjectionStateLabel(null), 'Relational only');
    expect(knowledgeProjectionStateLabel(_projection('queued')), 'Queued');
    expect(
      knowledgeProjectionStateLabel(
        _projection('processing', operation: 'publish'),
      ),
      'Indexing',
    );
    expect(
      knowledgeProjectionStateLabel(
        _projection('processing', operation: 'reindex'),
      ),
      'Reindexing',
    );
    expect(
      knowledgeProjectionStateLabel(_projection('ready', isCurrentReady: true)),
      'Searchable',
    );
    expect(
      knowledgeProjectionStateLabel(_projection('ready')),
      'Stale provider configuration',
    );
    expect(knowledgeProjectionStateLabel(_projection('failed')), 'Failed');
    expect(
      knowledgeProjectionStateLabel(_projection('cancelled')),
      'Cancelled',
    );
    expect(
      knowledgeProjectionStateLabel(const <String, Object?>{}),
      'Relational only',
    );
    expect(knowledgeProjectionStateLabel(_projection('paused')), 'paused');
  });

  test(
    'projection summaries expose safe target, match, time, and version labels',
    () {
      expect(knowledgeProjectionTargetLabel(null), isEmpty);
      expect(
        knowledgeProjectionTargetLabel(const <String, Object?>{
          'Provider': 'generic',
        }),
        'generic',
      );
      expect(
        knowledgeProjectionTargetLabel(const <String, Object?>{
          'TargetFingerprint': 'short',
        }),
        'short',
      );
      expect(
        knowledgeProjectionTargetLabel(const <String, Object?>{
          'Provider': 'generic',
          'TargetFingerprint': '1234567890123456',
        }),
        'generic · 123456789012',
      );
      expect(knowledgeProjectionMatchLabel(null), 'No');
      expect(knowledgeProjectionMatchLabel(_projection('queued')), 'Pending');
      expect(
        knowledgeProjectionMatchLabel(
          _projection('ready', isCurrentReady: true),
        ),
        'Yes',
      );
      expect(knowledgeProjectionMatchLabel(_projection('failed')), 'No');
      expect(knowledgeProjectionLastEvent(null), isEmpty);
      expect(
        knowledgeProjectionLastEvent(const <String, Object?>{
          'RequestedAt': 'request',
          'StartedAt': 'start',
          'FailedAt': 'failure',
          'CompletedAt': 'complete',
        }),
        'complete',
      );
      expect(
        knowledgeProjectionLastEvent(const <String, Object?>{
          'RequestedAt': 'request',
          'FailedAt': 'failure',
        }),
        'failure',
      );
      expect(
        knowledgeProjectionLastEvent(const <String, Object?>{
          'RequestedAt': 'request',
          'StartedAt': 'start',
        }),
        'start',
      );
      expect(
        knowledgeProjectionLastEvent(const <String, Object?>{
          'RequestedAt': 'request',
        }),
        'request',
      );
      expect(
        knowledgePackVersionLabel(const <String, Object?>{
          'KnowledgePackVersion': <String, Object?>{'VersionNumber': 8},
        }),
        'v8',
      );
      expect(
        knowledgePackVersionLabel(const <String, Object?>{
          'KnowledgePackVersionId': 'short-id',
        }),
        'short-id',
      );
      expect(
        knowledgePackVersionLabel(const <String, Object?>{
          'KnowledgePackVersionId': '1234567890123456',
        }),
        '123456789012',
      );
    },
  );

  test('failure details redact credentials, endpoints, and machine paths', () {
    expect(sanitizeKnowledgeProjectionFailure(null), isEmpty);
    final sanitized = sanitizeKnowledgeProjectionFailure(
      ' failed\n token=abc https://internal.example/a /home/user/config ',
    );
    expect(sanitized, contains('[credential redacted]'));
    expect(sanitized, contains('[endpoint]'));
    expect(sanitized, contains('[path]'));
    expect(sanitized, isNot(contains('abc')));
    expect(
      sanitizeKnowledgeProjectionFailure('1234567890', limit: 6),
      '12345…',
    );
  });

  test('active and terminal predicates use only contract statuses', () {
    expect(knowledgeProjectionIsActive(_projection('processing')), isTrue);
    expect(knowledgeProjectionIsActive(_projection('ready')), isFalse);
    expect(knowledgeProjectionIsTerminal(_projection('ready')), isTrue);
    expect(knowledgeProjectionIsTerminal(_projection('failed')), isTrue);
    expect(knowledgeProjectionIsTerminal(_projection('cancelled')), isTrue);
    expect(knowledgeProjectionIsTerminal(_projection('queued')), isFalse);
  });
}

AcpRow _projection(
  String status, {
  String operation = 'publish',
  bool isCurrentReady = false,
}) => <String, Object?>{
  'Status': status,
  'Operation': operation,
  'IsCurrentReady': isCurrentReady,
};
