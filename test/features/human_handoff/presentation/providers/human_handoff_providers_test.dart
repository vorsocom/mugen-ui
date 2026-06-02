import 'dart:collection';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/human_handoff/application/dto/human_handoff_inputs.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_delivery_result_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_event_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_session_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_tenant_option_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_transcript_item_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/repositories/human_handoff_repository.dart';
import 'package:mugen_ui/features/human_handoff/presentation/providers/human_handoff_providers.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

void main() {
  test('loadInitialData selects tenant, sessions, and transcript', () async {
    final repository = _FakeHumanHandoffRepository();
    final container = _buildContainer(repository);
    addTearDown(container.dispose);

    await container
        .read(humanHandoffControllerProvider.notifier)
        .loadInitialData();

    final state = container.read(humanHandoffControllerProvider);
    expect(state.selectedTenantId, 'tenant-1');
    expect(state.selectedSessionId, 'session-1');
    expect(state.sessions, hasLength(1));
    expect(state.transcript.first.sequenceNo, 1);
    expect(repository.sessionQueries.single.status, 'active');
    expect(repository.eventStreamQueries.single.tenantId, 'tenant-1');
  });

  test('filter changes reload sessions with updated query inputs', () async {
    final repository = _FakeHumanHandoffRepository();
    final container = _buildContainer(repository);
    addTearDown(container.dispose);

    final notifier = container.read(humanHandoffControllerProvider.notifier);
    await notifier.loadInitialData();
    await notifier.setPlatformFilter('web');
    await notifier.setServiceRouteFilter('support');
    await notifier.setOwnerFilter('agent-1');

    final query = repository.sessionQueries.last;
    expect(query.pageRequest.page, 1);
    expect(query.platform, 'web');
    expect(query.serviceRouteKey, 'support');
    expect(query.ownerUserId, 'agent-1');
  });

  test('successful reply clears draft and refreshes session data', () async {
    final repository = _FakeHumanHandoffRepository();
    final container = _buildContainer(repository);
    addTearDown(container.dispose);

    final notifier = container.read(humanHandoffControllerProvider.notifier);
    await notifier.loadInitialData();
    notifier.updateDraft('Thanks for waiting.');

    final sent = await notifier.sendReply();

    expect(sent, isTrue);
    final state = container.read(humanHandoffControllerProvider);
    expect(state.draftText, isEmpty);
    expect(state.pendingReplyMessageId, isNull);
    expect(repository.replyInputs.single.content, 'Thanks for waiting.');
    expect(repository.sessionQueries.length, 2);
  });

  test(
    'live transcript event refreshes sessions and appends new rows',
    () async {
      final repository = _FakeHumanHandoffRepository();
      final container = _buildContainer(repository);
      addTearDown(container.dispose);

      final notifier = container.read(humanHandoffControllerProvider.notifier);
      await notifier.loadInitialData();

      repository.eventController.add(
        const Result<HumanHandoffEventEntity>.success(
          HumanHandoffEventEntity(
            eventId: 'tenant-1:event-3',
            tenantId: 'tenant-1',
            sessionId: 'session-1',
            eventType: 'handoff.transcript_appended',
            sequenceNo: 3,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(humanHandoffControllerProvider);
      expect(state.transcript.map((item) => item.sequenceNo), <int>[1, 2, 3]);
      expect(state.latestTranscriptSequenceNo, 3);
      expect(state.isLiveListening, isTrue);
      expect(repository.sessionQueries.length, 2);
      expect(repository.transcriptQueries.last.afterSequenceNo, 2);
    },
  );

  test('failed delivery preserves draft and retry reuses message id', () async {
    final repository = _FakeHumanHandoffRepository(
      deliveryResults: Queue<HumanHandoffDeliveryResultEntity>.from(
        const <HumanHandoffDeliveryResultEntity>[
          HumanHandoffDeliveryResultEntity(
            decision: 'replied',
            deliveryStatus: 'failed',
            deliveryError: 'delivery failed',
          ),
          HumanHandoffDeliveryResultEntity(
            decision: 'replied',
            deliveryStatus: 'sent',
          ),
        ],
      ),
    );
    final container = _buildContainer(repository);
    addTearDown(container.dispose);

    final notifier = container.read(humanHandoffControllerProvider.notifier);
    await notifier.loadInitialData();
    notifier.updateDraft('Please try again.');

    final failed = await notifier.sendReply();
    final retainedMessageId = repository.replyInputs.single.messageId;
    final retry = await notifier.sendReply();

    expect(failed, isFalse);
    expect(retry, isTrue);
    expect(repository.replyInputs, hasLength(2));
    expect(repository.replyInputs.last.messageId, retainedMessageId);
    expect(container.read(humanHandoffControllerProvider).draftText, isEmpty);
  });

  test('releaseSelected posts reason and refreshes sessions', () async {
    final repository = _FakeHumanHandoffRepository();
    final container = _buildContainer(repository);
    addTearDown(container.dispose);

    final notifier = container.read(humanHandoffControllerProvider.notifier);
    await notifier.loadInitialData();

    final released = await notifier.releaseSelected(reason: 'resolved');

    expect(released, isTrue);
    expect(repository.deactivateInputs.single.reason, 'resolved');
    expect(repository.sessionQueries.length, 2);
  });
}

ProviderContainer _buildContainer(_FakeHumanHandoffRepository repository) {
  return ProviderContainer(
    overrides: <Override>[
      humanHandoffRepositoryProvider.overrideWithValue(repository),
      authControllerProvider.overrideWith(() => _TestAuthController()),
    ],
  );
}

class _FakeHumanHandoffRepository implements HumanHandoffRepository {
  _FakeHumanHandoffRepository({
    Queue<HumanHandoffDeliveryResultEntity>? deliveryResults,
  }) : deliveryResults =
           deliveryResults ??
           Queue<HumanHandoffDeliveryResultEntity>.from(
             const <HumanHandoffDeliveryResultEntity>[
               HumanHandoffDeliveryResultEntity(
                 decision: 'replied',
                 deliveryStatus: 'sent',
               ),
             ],
           );

  final Queue<HumanHandoffDeliveryResultEntity> deliveryResults;
  final StreamController<Result<HumanHandoffEventEntity>> eventController =
      StreamController<Result<HumanHandoffEventEntity>>.broadcast();
  final List<HumanHandoffSessionListQuery> sessionQueries =
      <HumanHandoffSessionListQuery>[];
  final List<HumanHandoffTranscriptQuery> transcriptQueries =
      <HumanHandoffTranscriptQuery>[];
  final List<HumanHandoffEventStreamQuery> eventStreamQueries =
      <HumanHandoffEventStreamQuery>[];
  final List<HumanHandoffReplyInput> replyInputs = <HumanHandoffReplyInput>[];
  final List<HumanHandoffDeactivateInput> deactivateInputs =
      <HumanHandoffDeactivateInput>[];

  @override
  Future<Result<List<HumanHandoffTenantOptionEntity>>> fetchTenants({
    int top = 200,
  }) async {
    return const Result<List<HumanHandoffTenantOptionEntity>>.success(
      <HumanHandoffTenantOptionEntity>[
        HumanHandoffTenantOptionEntity(id: 'tenant-1', name: 'Tenant One'),
      ],
    );
  }

  @override
  Future<Result<PageResult<HumanHandoffSessionEntity>>> fetchSessions(
    HumanHandoffSessionListQuery query,
  ) async {
    sessionQueries.add(query);
    return Result<PageResult<HumanHandoffSessionEntity>>.success(
      PageResult<HumanHandoffSessionEntity>(
        items: <HumanHandoffSessionEntity>[_activeSession],
        total: 1,
        page: query.pageRequest.page,
        pageSize: query.pageRequest.pageSize,
      ),
    );
  }

  @override
  Future<Result<HumanHandoffTranscriptResultEntity>> listTranscript(
    HumanHandoffTranscriptQuery query,
  ) async {
    transcriptQueries.add(query);
    final items = query.afterSequenceNo == null
        ? const <HumanHandoffTranscriptItemEntity>[
            HumanHandoffTranscriptItemEntity(
              sequenceNo: 1,
              role: 'user',
              content: 'hello',
              source: 'human_handoff_user_turn',
            ),
            HumanHandoffTranscriptItemEntity(
              sequenceNo: 2,
              role: 'assistant',
              content: 'human reply',
              source: 'human_handoff',
            ),
          ]
        : const <HumanHandoffTranscriptItemEntity>[
            HumanHandoffTranscriptItemEntity(
              sequenceNo: 3,
              role: 'user',
              content: 'new turn',
              source: 'human_handoff_user_turn',
            ),
          ];
    return Result<HumanHandoffTranscriptResultEntity>.success(
      HumanHandoffTranscriptResultEntity(
        items: items,
        count: items.length,
        latestSequenceNo: items.last.sequenceNo,
        hasMore: false,
      ),
    );
  }

  @override
  Stream<Result<HumanHandoffEventEntity>> streamEvents(
    HumanHandoffEventStreamQuery query,
  ) {
    eventStreamQueries.add(query);
    return eventController.stream;
  }

  @override
  Future<Result<HumanHandoffDeliveryResultEntity>> sendReply(
    HumanHandoffReplyInput input,
  ) async {
    replyInputs.add(input);
    return Result<HumanHandoffDeliveryResultEntity>.success(
      deliveryResults.removeFirst(),
    );
  }

  @override
  Future<Result<void>> deactivate(HumanHandoffDeactivateInput input) async {
    deactivateInputs.add(input);
    return const Result<void>.success(null);
  }
}

class _TestAuthController extends AuthController {
  @override
  AuthControllerState build() {
    return const AuthControllerState(
      isLoading: false,
      session: AuthSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        userId: 'agent-1',
        username: 'Support Agent',
        roles: <String>['com.vorsocomputing.mugen.acp:administrator'],
      ),
    );
  }
}

const HumanHandoffSessionEntity _activeSession = HumanHandoffSessionEntity(
  id: 'session-1',
  tenantId: 'tenant-1',
  scopeKey: 'web:room:user',
  platform: 'web',
  status: 'active',
  roomId: 'room-1',
  senderId: 'sender-1',
);
