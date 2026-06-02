import 'dart:collection';
import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:mugen_ui/features/human_handoff/presentation/widgets/human_handoff_panel.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

void main() {
  testWidgets('HumanHandoffPanel renders inbox and sends reply', (
    tester,
  ) async {
    final repository = _FakeHumanHandoffRepository();
    await _pumpPanel(tester, repository);

    expect(find.text('Tenant One'), findsOneWidget);
    expect(find.text('web:room:user'), findsWidgets);
    expect(find.text('hello'), findsOneWidget);
    expect(find.text('Human Reply'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('human-handoff-reply-field')),
      'Human response',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('human-handoff-send-reply-button')),
    );
    await tester.tap(find.byKey(const Key('human-handoff-send-reply-button')));
    await tester.pumpAndSettle();

    expect(repository.replyInputs.single.content, 'Human response');
  });

  testWidgets('HumanHandoffPanel preserves draft on delivery failure', (
    tester,
  ) async {
    final repository = _FakeHumanHandoffRepository(
      deliveryResults: Queue<HumanHandoffDeliveryResultEntity>.from(
        const <HumanHandoffDeliveryResultEntity>[
          HumanHandoffDeliveryResultEntity(
            decision: 'replied',
            deliveryStatus: 'failed',
            deliveryError: 'delivery failed',
          ),
        ],
      ),
    );
    await _pumpPanel(tester, repository);

    await tester.enterText(
      find.byKey(const Key('human-handoff-reply-field')),
      'Retryable response',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('human-handoff-send-reply-button')),
    );
    await tester.tap(find.byKey(const Key('human-handoff-send-reply-button')));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText && widget.data == 'delivery failed',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    expect(repository.replyInputs.single.content, 'Retryable response');
  });

  testWidgets('HumanHandoffPanel disables composer for inactive sessions', (
    tester,
  ) async {
    final repository = _FakeHumanHandoffRepository(
      sessions: const <HumanHandoffSessionEntity>[
        HumanHandoffSessionEntity(
          id: 'session-2',
          tenantId: 'tenant-1',
          scopeKey: 'web:inactive:user',
          platform: 'web',
          status: 'inactive',
        ),
      ],
    );
    await _pumpPanel(tester, repository);

    final composer = tester.widget<TextField>(
      find.byKey(const Key('human-handoff-reply-field')),
    );
    expect(composer.enabled, isFalse);
    expect(find.widgetWithText(FilledButton, 'Send'), findsOneWidget);
    final sendButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Send'),
    );
    expect(sendButton.onPressed, isNull);
  });

  testWidgets('HumanHandoffPanel releases session with optional reason', (
    tester,
  ) async {
    final repository = _FakeHumanHandoffRepository();
    await _pumpPanel(tester, repository);

    await tester.tap(find.widgetWithText(TextButton, 'Release'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'resolved');
    await tester.tap(find.widgetWithText(FilledButton, 'Release'));
    await tester.pumpAndSettle();

    expect(repository.deactivateInputs.single.reason, 'resolved');
  });
}

Future<void> _pumpPanel(
  WidgetTester tester,
  _FakeHumanHandoffRepository repository,
) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        humanHandoffRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(() => _TestAuthController()),
      ],
      child: const MaterialApp(home: Scaffold(body: HumanHandoffPanel())),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeHumanHandoffRepository implements HumanHandoffRepository {
  _FakeHumanHandoffRepository({
    this.sessions = const <HumanHandoffSessionEntity>[_activeSession],
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

  final List<HumanHandoffSessionEntity> sessions;
  final StreamController<Result<HumanHandoffEventEntity>> eventController =
      StreamController<Result<HumanHandoffEventEntity>>.broadcast();
  final Queue<HumanHandoffDeliveryResultEntity> deliveryResults;
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
    return Result<PageResult<HumanHandoffSessionEntity>>.success(
      PageResult<HumanHandoffSessionEntity>(
        items: sessions,
        total: sessions.length,
        page: query.pageRequest.page,
        pageSize: query.pageRequest.pageSize,
      ),
    );
  }

  @override
  Future<Result<HumanHandoffTranscriptResultEntity>> listTranscript(
    HumanHandoffTranscriptQuery query,
  ) async {
    const items = <HumanHandoffTranscriptItemEntity>[
      HumanHandoffTranscriptItemEntity(
        sequenceNo: 1,
        role: 'user',
        content: 'hello',
        source: 'human_handoff_user_turn',
      ),
      HumanHandoffTranscriptItemEntity(
        sequenceNo: 2,
        role: 'assistant',
        content: <String, Object>{'text': 'human reply'},
        source: 'human_handoff',
      ),
    ];
    return const Result<HumanHandoffTranscriptResultEntity>.success(
      HumanHandoffTranscriptResultEntity(
        items: items,
        count: 2,
        latestSequenceNo: 2,
        hasMore: false,
      ),
    );
  }

  @override
  Stream<Result<HumanHandoffEventEntity>> streamEvents(
    HumanHandoffEventStreamQuery query,
  ) {
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
