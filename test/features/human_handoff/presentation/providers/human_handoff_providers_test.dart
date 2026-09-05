import 'dart:collection';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/human_handoff/application/dto/human_handoff_inputs.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_delivery_result_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_event_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_filter_options_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_session_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_tenant_option_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_transcript_item_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/repositories/human_handoff_repository.dart';
import 'package:mugen_ui/features/human_handoff/presentation/providers/human_handoff_providers.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

void main() {
  test('denied live access stops retries until an explicit refresh', () async {
    final repository = _FakeHumanHandoffRepository();
    final container = _buildContainer(repository);
    addTearDown(container.dispose);
    final notifier = container.read(humanHandoffControllerProvider.notifier);
    await notifier.loadInitialData();
    repository.eventController.add(
      const Result<HumanHandoffEventEntity>.failure(
        ApiFailure(403, 'Forbidden'),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5300));
    final state = container.read(humanHandoffControllerProvider);
    expect(state.liveStatus, HumanHandoffLiveStatus.unavailable);
    expect(state.liveErrorMessage, contains('Access to live handoff updates'));
    expect(repository.eventStreamQueries, hasLength(1));
    await notifier.refresh();
    expect(repository.eventStreamQueries, hasLength(2));
  });

  test(
    'late handoff data and failures cannot repopulate an ineligible tenant',
    () async {
      for (final failure in [false, true]) {
        final repository = _FakeHumanHandoffRepository();
        final container = _buildContainer(repository);
        addTearDown(container.dispose);
        final controller = container.read(
          humanHandoffControllerProvider.notifier,
        );
        await controller.loadInitialData();
        final options = Completer<Result<HumanHandoffFilterOptionsEntity>>();
        final sessions =
            Completer<Result<PageResult<HumanHandoffSessionEntity>>>();
        final transcript =
            Completer<Result<HumanHandoffTranscriptResultEntity>>();
        repository.nextOptionsResponse = options;
        repository.nextSessionsResponse = sessions;
        repository.nextTranscriptResponse = transcript;
        final pending = Future.wait([
          controller.loadFilterOptions(),
          controller.loadSessions(),
          controller.loadTranscript(),
        ]);
        repository.tenants = const [];
        await controller.loadTenants();
        options.complete(
          failure
              ? const Result.failure(ApiFailure(403, 'Old tenant denied.'))
              : const Result.success(
                  HumanHandoffFilterOptionsEntity(
                    owners: [
                      HumanHandoffReferenceOptionEntity(
                        id: 'old-owner',
                        title: 'Private old owner',
                      ),
                    ],
                    serviceRoutes: [],
                  ),
                ),
        );
        sessions.complete(
          failure
              ? const Result.failure(ApiFailure(403, 'Old tenant denied.'))
              : const Result.success(
                  PageResult(
                    items: [_activeSession],
                    total: 1,
                    page: 1,
                    pageSize: 15,
                  ),
                ),
        );
        transcript.complete(
          failure
              ? const Result.failure(ApiFailure(403, 'Old tenant denied.'))
              : const Result.success(_privateTranscript),
        );
        await pending;
        expect(controller.state.selectedTenantId, isNull);
        expect(controller.state.ownerOptions, isEmpty);
        expect(controller.state.serviceRouteOptions, isEmpty);
        expect(controller.state.sessions, isEmpty);
        expect(controller.state.transcript, isEmpty);
        expect(controller.state.errorMessage, isNull);
        expect(controller.state.isLoadingFilterOptions, isFalse);
        expect(controller.state.isLoadingSessions, isFalse);
        expect(controller.state.isLoadingTranscript, isFalse);
      }
    },
  );

  test('tenant selection discards old transcripts and reply drafts', () async {
    final repository = _FakeHumanHandoffRepository();
    final container = _buildContainer(repository);
    addTearDown(container.dispose);
    final controller = container.read(humanHandoffControllerProvider.notifier);
    await controller.loadInitialData();
    controller.updateDraft('Reply intended for the original tenant.');
    final transcript = Completer<Result<HumanHandoffTranscriptResultEntity>>();
    repository.nextTranscriptResponse = transcript;
    final oldLoad = controller.loadTranscript();
    await controller.selectTenant('tenant-2');
    final currentTranscript = controller.state.transcript;
    transcript.complete(const Result.success(_privateTranscript));
    await oldLoad;
    expect(controller.state.transcript, currentTranscript);
    expect(controller.state.draftText, isEmpty);
    expect(controller.state.pendingReplyMessageId, isNull);
  });

  test(
    'removing the selected session invalidates its pending transcript',
    () async {
      final repository = _FakeHumanHandoffRepository();
      final container = _buildContainer(repository);
      addTearDown(container.dispose);
      final controller = container.read(
        humanHandoffControllerProvider.notifier,
      );
      await controller.loadInitialData();
      final transcript =
          Completer<Result<HumanHandoffTranscriptResultEntity>>();
      repository.nextTranscriptResponse = transcript;
      final oldLoad = controller.loadTranscript();
      repository.nextSessionsResponse = Completer()
        ..complete(
          const Result.success(
            PageResult(items: [], total: 0, page: 1, pageSize: 15),
          ),
        );
      await controller.loadSessions();
      transcript.complete(const Result.success(_privateTranscript));
      await oldLoad;
      expect(controller.state.selectedSessionId, isNull);
      expect(controller.state.transcript, isEmpty);
      expect(controller.state.isLoadingTranscript, isFalse);
    },
  );

  test(
    'an old tenant list cannot undo the latest eligibility result',
    () async {
      final repository = _FakeHumanHandoffRepository();
      final container = _buildContainer(repository);
      addTearDown(container.dispose);
      final controller = container.read(
        humanHandoffControllerProvider.notifier,
      );
      await controller.loadInitialData();
      final originalTenants = repository.tenants;
      final tenants = Completer<Result<List<HumanHandoffTenantOptionEntity>>>();
      repository.nextTenantsResponse = tenants;
      final oldLoad = controller.loadTenants();
      repository.tenants = const [];
      await controller.loadTenants();
      tenants.complete(Result.success(originalTenants));
      await oldLoad;
      expect(controller.state.selectedTenantId, isNull);
      expect(controller.state.tenants, isEmpty);
    },
  );

  test(
    'refresh replaces an unavailable tenant and clears its conversation state',
    () async {
      final repository = _FakeHumanHandoffRepository();
      final container = _buildContainer(repository);
      addTearDown(container.dispose);
      final controller = container.read(
        humanHandoffControllerProvider.notifier,
      );
      await controller.loadInitialData();
      controller.updateDraft('Private reply for tenant one.');
      repository.tenants = const [
        HumanHandoffTenantOptionEntity(id: 'tenant-2', name: 'Tenant Two'),
      ];
      await controller.loadTenants();
      expect(controller.state.selectedTenantId, 'tenant-2');
      expect(controller.state.sessions, isEmpty);
      expect(controller.state.transcript, isEmpty);
      expect(controller.state.selectedSessionId, isNull);
      expect(controller.state.latestTranscriptSequenceNo, isNull);
      expect(controller.state.draftText, isEmpty);
      expect(controller.state.ownerOptions, isEmpty);
      expect(controller.state.serviceRouteOptions, isEmpty);
      expect(controller.state.liveStatus, HumanHandoffLiveStatus.offline);

      await controller.refresh();
      expect(repository.sessionQueries.last.tenantId, 'tenant-2');
      expect(repository.eventStreamQueries.last.tenantId, 'tenant-2');
      expect(controller.state.sessions, isNotEmpty);

      repository.tenants = const [];
      await controller.refresh();
      expect(controller.state.selectedTenantId, isNull);
      expect(controller.state.sessions, isEmpty);
      expect(controller.state.transcript, isEmpty);
      expect(controller.state.liveStatus, HumanHandoffLiveStatus.offline);
    },
  );

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

  test('transient live failure enters reconnecting state', () async {
    final repository = _FakeHumanHandoffRepository();
    final container = _buildContainer(repository);
    addTearDown(container.dispose);

    await container
        .read(humanHandoffControllerProvider.notifier)
        .loadInitialData();
    repository.eventController.add(
      const Result<HumanHandoffEventEntity>.failure(
        NetworkFailure('Temporary stream interruption.'),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(humanHandoffControllerProvider);
    expect(state.liveStatus, HumanHandoffLiveStatus.reconnecting);
    expect(state.isLiveListening, isFalse);
    expect(state.liveErrorMessage, 'Temporary stream interruption.');
  });

  test('uncaught live stream errors enter reconnecting state', () async {
    final repository = _FakeHumanHandoffRepository();
    final container = _buildContainer(repository);
    addTearDown(container.dispose);

    await container
        .read(humanHandoffControllerProvider.notifier)
        .loadInitialData();
    repository.eventController.addError(StateError('socket closed'));
    await Future<void>.delayed(Duration.zero);

    final state = container.read(humanHandoffControllerProvider);
    expect(state.liveStatus, HumanHandoffLiveStatus.reconnecting);
    expect(state.liveErrorMessage, 'Handoff event stream disconnected.');
  });

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
  Completer<Result<HumanHandoffFilterOptionsEntity>>? nextOptionsResponse;
  Completer<Result<PageResult<HumanHandoffSessionEntity>>>?
  nextSessionsResponse;
  Completer<Result<HumanHandoffTranscriptResultEntity>>? nextTranscriptResponse;
  Completer<Result<List<HumanHandoffTenantOptionEntity>>>? nextTenantsResponse;
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

  List<HumanHandoffTenantOptionEntity> tenants = const [
    HumanHandoffTenantOptionEntity(id: 'tenant-1', name: 'Tenant One'),
  ];
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
    final pending = nextTenantsResponse;
    nextTenantsResponse = null;
    if (pending != null) {
      return pending.future;
    }
    return Result<List<HumanHandoffTenantOptionEntity>>.success(tenants);
  }

  @override
  Future<Result<HumanHandoffFilterOptionsEntity>> fetchFilterOptions({
    required String tenantId,
    int top = 200,
  }) async {
    final pending = nextOptionsResponse;
    nextOptionsResponse = null;
    if (pending != null) {
      return pending.future;
    }
    return const Result<HumanHandoffFilterOptionsEntity>.success(
      HumanHandoffFilterOptionsEntity(
        owners: <HumanHandoffReferenceOptionEntity>[
          HumanHandoffReferenceOptionEntity(
            id: 'agent-1',
            title: 'agent@example.com',
          ),
        ],
        serviceRoutes: <HumanHandoffReferenceOptionEntity>[
          HumanHandoffReferenceOptionEntity(id: 'support', title: 'Support'),
        ],
      ),
    );
  }

  @override
  Future<Result<PageResult<HumanHandoffSessionEntity>>> fetchSessions(
    HumanHandoffSessionListQuery query,
  ) async {
    sessionQueries.add(query);
    final pending = nextSessionsResponse;
    nextSessionsResponse = null;
    if (pending != null) {
      return pending.future;
    }
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
    final pending = nextTranscriptResponse;
    nextTranscriptResponse = null;
    if (pending != null) {
      return pending.future;
    }
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
    HumanHandoffEventStreamQuery query, {
    void Function()? onConnected,
  }) {
    eventStreamQueries.add(query);
    onConnected?.call();
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

const _privateTranscript = HumanHandoffTranscriptResultEntity(
  items: [
    HumanHandoffTranscriptItemEntity(
      sequenceNo: 999,
      role: 'user',
      content: 'Private old tenant conversation.',
      source: 'human_handoff_user_turn',
    ),
  ],
  count: 1,
  latestSequenceNo: 999,
  hasMore: false,
);
