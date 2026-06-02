// coverage:ignore-file
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/human_handoff/application/dto/human_handoff_inputs.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_event_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_session_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_tenant_option_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_transcript_item_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/repositories/human_handoff_repository.dart';
import 'package:mugen_ui/features/human_handoff/infrastructure/repositories/human_handoff_repository_impl.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class HumanHandoffState {
  const HumanHandoffState({
    required this.tenants,
    required this.sessions,
    required this.transcript,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.statusFilter,
    required this.platformFilter,
    required this.serviceRouteFilter,
    required this.ownerFilter,
    required this.draftText,
    required this.isLoadingTenants,
    required this.isLoadingSessions,
    required this.isLoadingTranscript,
    required this.isReplying,
    required this.isReleasing,
    required this.hasMoreTranscript,
    required this.isLiveListening,
    this.latestTranscriptSequenceNo,
    this.selectedTenantId,
    this.selectedSessionId,
    this.pendingReplyMessageId,
    this.lastDeliveryError,
    this.errorMessage,
    this.liveErrorMessage,
  });

  final List<HumanHandoffTenantOptionEntity> tenants;
  final List<HumanHandoffSessionEntity> sessions;
  final List<HumanHandoffTranscriptItemEntity> transcript;
  final int page;
  final int pageSize;
  final int total;
  final String statusFilter;
  final String platformFilter;
  final String serviceRouteFilter;
  final String ownerFilter;
  final String draftText;
  final bool isLoadingTenants;
  final bool isLoadingSessions;
  final bool isLoadingTranscript;
  final bool isReplying;
  final bool isReleasing;
  final bool hasMoreTranscript;
  final bool isLiveListening;
  final int? latestTranscriptSequenceNo;
  final String? selectedTenantId;
  final String? selectedSessionId;
  final String? pendingReplyMessageId;
  final String? lastDeliveryError;
  final String? errorMessage;
  final String? liveErrorMessage;

  int get pages {
    if (pageSize <= 0) {
      return 1;
    }
    final computed = (total / pageSize).ceil();
    return computed <= 0 ? 1 : computed;
  }

  HumanHandoffSessionEntity? get selectedSession {
    final id = selectedSessionId;
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final session in sessions) {
      if (session.id == id) {
        return session;
      }
    }
    return null;
  }

  bool get canReply {
    final session = selectedSession;
    return session != null &&
        session.isActive &&
        draftText.trim().isNotEmpty &&
        !isReplying &&
        !isReleasing;
  }

  HumanHandoffState copyWith({
    List<HumanHandoffTenantOptionEntity>? tenants,
    List<HumanHandoffSessionEntity>? sessions,
    List<HumanHandoffTranscriptItemEntity>? transcript,
    int? page,
    int? pageSize,
    int? total,
    String? statusFilter,
    String? platformFilter,
    String? serviceRouteFilter,
    String? ownerFilter,
    String? draftText,
    bool? isLoadingTenants,
    bool? isLoadingSessions,
    bool? isLoadingTranscript,
    bool? isReplying,
    bool? isReleasing,
    bool? hasMoreTranscript,
    bool? isLiveListening,
    int? latestTranscriptSequenceNo,
    String? selectedTenantId,
    String? selectedSessionId,
    String? pendingReplyMessageId,
    String? lastDeliveryError,
    String? errorMessage,
    String? liveErrorMessage,
    bool clearSelectedTenant = false,
    bool clearSelectedSession = false,
    bool clearPendingReplyMessage = false,
    bool clearLastDeliveryError = false,
    bool clearError = false,
    bool clearLiveError = false,
    bool clearLatestTranscriptSequence = false,
  }) {
    return HumanHandoffState(
      tenants: tenants ?? this.tenants,
      sessions: sessions ?? this.sessions,
      transcript: transcript ?? this.transcript,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      total: total ?? this.total,
      statusFilter: statusFilter ?? this.statusFilter,
      platformFilter: platformFilter ?? this.platformFilter,
      serviceRouteFilter: serviceRouteFilter ?? this.serviceRouteFilter,
      ownerFilter: ownerFilter ?? this.ownerFilter,
      draftText: draftText ?? this.draftText,
      isLoadingTenants: isLoadingTenants ?? this.isLoadingTenants,
      isLoadingSessions: isLoadingSessions ?? this.isLoadingSessions,
      isLoadingTranscript: isLoadingTranscript ?? this.isLoadingTranscript,
      isReplying: isReplying ?? this.isReplying,
      isReleasing: isReleasing ?? this.isReleasing,
      hasMoreTranscript: hasMoreTranscript ?? this.hasMoreTranscript,
      isLiveListening: isLiveListening ?? this.isLiveListening,
      latestTranscriptSequenceNo: clearLatestTranscriptSequence
          ? null
          : (latestTranscriptSequenceNo ?? this.latestTranscriptSequenceNo),
      selectedTenantId: clearSelectedTenant
          ? null
          : (selectedTenantId ?? this.selectedTenantId),
      selectedSessionId: clearSelectedSession
          ? null
          : (selectedSessionId ?? this.selectedSessionId),
      pendingReplyMessageId: clearPendingReplyMessage
          ? null
          : (pendingReplyMessageId ?? this.pendingReplyMessageId),
      lastDeliveryError: clearLastDeliveryError
          ? null
          : (lastDeliveryError ?? this.lastDeliveryError),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      liveErrorMessage: clearLiveError
          ? null
          : (liveErrorMessage ?? this.liveErrorMessage),
    );
  }
}

final humanHandoffRepositoryProvider = Provider<HumanHandoffRepository>((ref) {
  return HumanHandoffRepositoryImpl(
    appConfig: ref.watch(appConfigProvider),
    authenticatedHttpClient: ref.watch(authenticatedHttpClientProvider),
    cookieStore: ref.watch(cookieStoreProvider),
  );
});

final humanHandoffControllerProvider =
    StateNotifierProvider<HumanHandoffController, HumanHandoffState>((ref) {
      return HumanHandoffController(ref);
    });

class HumanHandoffController extends StateNotifier<HumanHandoffState> {
  HumanHandoffController(this.ref)
    : super(
        const HumanHandoffState(
          tenants: <HumanHandoffTenantOptionEntity>[],
          sessions: <HumanHandoffSessionEntity>[],
          transcript: <HumanHandoffTranscriptItemEntity>[],
          page: 1,
          pageSize: 15,
          total: 0,
          statusFilter: 'active',
          platformFilter: '',
          serviceRouteFilter: '',
          ownerFilter: '',
          draftText: '',
          isLoadingTenants: false,
          isLoadingSessions: false,
          isLoadingTranscript: false,
          isReplying: false,
          isReleasing: false,
          hasMoreTranscript: false,
          isLiveListening: false,
        ),
      );

  final Ref ref;
  int _messageCounter = 0;
  StreamSubscription<Result<HumanHandoffEventEntity>>? _eventSubscription;
  Timer? _eventReconnectTimer;
  String? _streamTenantId;
  String? _lastEventId;
  bool _disposed = false;

  Future<void> loadInitialData() async {
    await loadTenants();
    if (state.selectedTenantId != null) {
      await loadSessions();
    }
    _startEventStream();
  }

  Future<void> loadTenants() async {
    state = state.copyWith(isLoadingTenants: true, clearError: true);
    final result = await ref
        .read(humanHandoffRepositoryProvider)
        .fetchTenants();
    if (result.isFailure) {
      _applyFailure(result.failure!, fallback: 'Could not load tenants.');
      state = state.copyWith(isLoadingTenants: false);
      return;
    }

    final tenants = result.data ?? const <HumanHandoffTenantOptionEntity>[];
    var selectedTenantId = state.selectedTenantId;
    if (!tenants.any((tenant) => tenant.id == selectedTenantId)) {
      selectedTenantId = tenants.isEmpty ? null : tenants.first.id;
    }

    state = state.copyWith(
      tenants: tenants,
      selectedTenantId: selectedTenantId,
      isLoadingTenants: false,
      sessions: tenants.isEmpty
          ? const <HumanHandoffSessionEntity>[]
          : state.sessions,
      transcript: tenants.isEmpty
          ? const <HumanHandoffTranscriptItemEntity>[]
          : state.transcript,
      hasMoreTranscript: tenants.isEmpty ? false : state.hasMoreTranscript,
      clearSelectedTenant: tenants.isEmpty,
      clearSelectedSession: tenants.isEmpty,
      clearLatestTranscriptSequence: tenants.isEmpty,
      clearError: true,
    );
    if (tenants.isEmpty) {
      _stopEventStream();
    }
  }

  Future<void> loadSessions({bool refreshTranscript = true}) async {
    final tenantId = state.selectedTenantId;
    if (tenantId == null || tenantId.isEmpty) {
      state = state.copyWith(
        sessions: const <HumanHandoffSessionEntity>[],
        transcript: const <HumanHandoffTranscriptItemEntity>[],
        total: 0,
        hasMoreTranscript: false,
        clearSelectedSession: true,
        clearLatestTranscriptSequence: true,
      );
      _stopEventStream();
      return;
    }

    state = state.copyWith(isLoadingSessions: true, clearError: true);
    final result = await ref
        .read(humanHandoffRepositoryProvider)
        .fetchSessions(
          HumanHandoffSessionListQuery(
            tenantId: tenantId,
            pageRequest: PageRequest(
              page: state.page,
              pageSize: state.pageSize,
            ),
            status: state.statusFilter,
            platform: state.platformFilter,
            serviceRouteKey: state.serviceRouteFilter,
            ownerUserId: state.ownerFilter,
          ),
        );
    if (result.isFailure) {
      _applyFailure(
        result.failure!,
        fallback: 'Could not load handoff sessions.',
      );
      state = state.copyWith(isLoadingSessions: false);
      return;
    }

    final page = result.data!;
    var selectedSessionId = state.selectedSessionId;
    if (!page.items.any((session) => session.id == selectedSessionId)) {
      selectedSessionId = page.items.isEmpty ? null : page.items.first.id;
    }

    state = state.copyWith(
      sessions: page.items,
      total: page.total,
      page: page.page,
      pageSize: page.pageSize,
      selectedSessionId: selectedSessionId,
      isLoadingSessions: false,
      transcript: selectedSessionId == null
          ? const <HumanHandoffTranscriptItemEntity>[]
          : state.transcript,
      hasMoreTranscript: selectedSessionId == null
          ? false
          : state.hasMoreTranscript,
      clearSelectedSession: selectedSessionId == null,
      clearLatestTranscriptSequence: selectedSessionId == null,
      clearError: true,
    );

    if (selectedSessionId != null && refreshTranscript) {
      await loadTranscript();
    }
  }

  Future<void> loadTranscript({bool incremental = false}) async {
    final tenantId = state.selectedTenantId;
    final sessionId = state.selectedSessionId;
    if (tenantId == null ||
        tenantId.isEmpty ||
        sessionId == null ||
        sessionId.isEmpty) {
      state = state.copyWith(
        transcript: const <HumanHandoffTranscriptItemEntity>[],
        hasMoreTranscript: false,
        clearLatestTranscriptSequence: true,
      );
      return;
    }

    final afterSequenceNo = incremental
        ? state.latestTranscriptSequenceNo
        : null;
    state = state.copyWith(isLoadingTranscript: true, clearError: true);
    final result = await ref
        .read(humanHandoffRepositoryProvider)
        .listTranscript(
          HumanHandoffTranscriptQuery(
            tenantId: tenantId,
            sessionId: sessionId,
            afterSequenceNo: afterSequenceNo,
          ),
        );
    if (result.isFailure) {
      _applyFailure(result.failure!, fallback: 'Could not load transcript.');
      state = state.copyWith(isLoadingTranscript: false);
      return;
    }

    final transcriptResult = result.data!;
    final transcript = incremental
        ? _mergeTranscriptItems(state.transcript, transcriptResult.items)
        : transcriptResult.items;
    final loadedLatestSequenceNo = _latestSequenceNo(transcript);
    final latestSequenceNo = transcriptResult.hasMore
        ? loadedLatestSequenceNo
        : (transcriptResult.latestSequenceNo ?? loadedLatestSequenceNo);

    state = state.copyWith(
      transcript: transcript,
      latestTranscriptSequenceNo: latestSequenceNo,
      hasMoreTranscript: transcriptResult.hasMore,
      isLoadingTranscript: false,
      clearError: true,
    );

    if (incremental &&
        transcriptResult.hasMore &&
        transcriptResult.items.isNotEmpty) {
      await loadTranscript(incremental: true);
    }
  }

  Future<void> selectTenant(String? tenantId) async {
    final normalized = tenantId?.trim();
    if (normalized == null ||
        normalized.isEmpty ||
        normalized == state.selectedTenantId) {
      return;
    }
    state = state.copyWith(
      selectedTenantId: normalized,
      page: 1,
      sessions: const <HumanHandoffSessionEntity>[],
      transcript: const <HumanHandoffTranscriptItemEntity>[],
      clearSelectedSession: true,
      clearLastDeliveryError: true,
      clearLatestTranscriptSequence: true,
    );
    await loadSessions();
    _startEventStream();
  }

  Future<void> selectSession(String sessionId) async {
    final normalized = sessionId.trim();
    if (normalized.isEmpty || normalized == state.selectedSessionId) {
      return;
    }
    state = state.copyWith(
      selectedSessionId: normalized,
      transcript: const <HumanHandoffTranscriptItemEntity>[],
      hasMoreTranscript: false,
      clearLastDeliveryError: true,
      clearLatestTranscriptSequence: true,
      clearError: true,
    );
    await loadTranscript();
  }

  Future<void> setStatusFilter(String value) async {
    state = state.copyWith(statusFilter: value, page: 1);
    await loadSessions();
  }

  Future<void> setPlatformFilter(String value) async {
    state = state.copyWith(platformFilter: value.trim(), page: 1);
    await loadSessions();
  }

  Future<void> setServiceRouteFilter(String value) async {
    state = state.copyWith(serviceRouteFilter: value.trim(), page: 1);
    await loadSessions();
  }

  Future<void> setOwnerFilter(String value) async {
    state = state.copyWith(ownerFilter: value.trim(), page: 1);
    await loadSessions();
  }

  Future<void> goToPage(int page) async {
    final nextPage = page < 1 ? 1 : page;
    state = state.copyWith(page: nextPage);
    await loadSessions();
  }

  void updateDraft(String value) {
    state = state.copyWith(draftText: value);
  }

  Future<bool> sendReply() async {
    final tenantId = state.selectedTenantId;
    final session = state.selectedSession;
    final content = state.draftText.trim();
    if (tenantId == null ||
        tenantId.isEmpty ||
        session == null ||
        content.isEmpty ||
        !session.isActive) {
      return false;
    }

    final messageId = state.pendingReplyMessageId ?? _nextMessageId();
    state = state.copyWith(
      isReplying: true,
      pendingReplyMessageId: messageId,
      clearError: true,
      clearLastDeliveryError: true,
    );

    final displayName = ref.read(authControllerProvider).session?.username;
    final result = await ref
        .read(humanHandoffRepositoryProvider)
        .sendReply(
          HumanHandoffReplyInput(
            tenantId: tenantId,
            sessionId: session.id,
            content: content,
            messageId: messageId,
            operatorDisplayName: displayName,
          ),
        );
    if (result.isFailure) {
      _applyFailure(result.failure!, fallback: 'Could not send reply.');
      state = state.copyWith(isReplying: false);
      return false;
    }

    final delivery = result.data!;
    if (delivery.isFailed) {
      state = state.copyWith(
        isReplying: false,
        lastDeliveryError:
            delivery.deliveryError ?? 'Reply was stored but delivery failed.',
        pendingReplyMessageId: messageId,
      );
      return false;
    }

    state = state.copyWith(
      isReplying: false,
      draftText: '',
      clearPendingReplyMessage: true,
      clearLastDeliveryError: true,
      clearError: true,
    );
    await loadSessions(refreshTranscript: false);
    if (state.selectedSessionId == session.id) {
      await loadTranscript(
        incremental: state.latestTranscriptSequenceNo != null,
      );
    }
    return true;
  }

  Future<bool> releaseSelected({String? reason}) async {
    final tenantId = state.selectedTenantId;
    final session = state.selectedSession;
    if (tenantId == null || tenantId.isEmpty || session == null) {
      return false;
    }

    state = state.copyWith(isReleasing: true, clearError: true);
    final result = await ref
        .read(humanHandoffRepositoryProvider)
        .deactivate(
          HumanHandoffDeactivateInput(
            tenantId: tenantId,
            sessionId: session.id,
            reason: reason,
          ),
        );
    if (result.isFailure) {
      _applyFailure(result.failure!, fallback: 'Could not release handoff.');
      state = state.copyWith(isReleasing: false);
      return false;
    }

    state = state.copyWith(
      isReleasing: false,
      draftText: '',
      clearPendingReplyMessage: true,
      clearLastDeliveryError: true,
      clearError: true,
    );
    await loadSessions();
    return true;
  }

  void _startEventStream() {
    final tenantId = state.selectedTenantId?.trim();
    if (tenantId == null || tenantId.isEmpty || _disposed) {
      _stopEventStream();
      return;
    }
    if (_eventSubscription != null && _streamTenantId == tenantId) {
      return;
    }

    final previousTenantId = _streamTenantId;
    _stopEventStream(keepLastEventId: previousTenantId == tenantId);
    if (previousTenantId != tenantId) {
      _lastEventId = null;
    }
    _streamTenantId = tenantId;
    state = state.copyWith(isLiveListening: true, clearLiveError: true);
    _eventSubscription = ref
        .read(humanHandoffRepositoryProvider)
        .streamEvents(
          HumanHandoffEventStreamQuery(
            tenantId: tenantId,
            lastEventId: _lastEventId,
          ),
        )
        .listen(
          (result) => unawaited(_handleEventResult(result)),
          onDone: _handleEventStreamDone,
        );
  }

  void _stopEventStream({bool keepLastEventId = false}) {
    _eventReconnectTimer?.cancel();
    _eventReconnectTimer = null;
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _streamTenantId = null;
    if (!keepLastEventId) {
      _lastEventId = null;
    }
    if (!_disposed && state.isLiveListening) {
      state = state.copyWith(isLiveListening: false);
    }
  }

  void _handleEventStreamDone() {
    _eventSubscription = null;
    if (_disposed || _streamTenantId == null) {
      return;
    }
    state = state.copyWith(isLiveListening: false);
    _scheduleEventReconnect();
  }

  void _scheduleEventReconnect() {
    if (_disposed || _streamTenantId == null) {
      return;
    }
    _eventReconnectTimer?.cancel();
    _eventReconnectTimer = Timer(const Duration(seconds: 5), _startEventStream);
  }

  Future<void> _handleEventResult(
    Result<HumanHandoffEventEntity> result,
  ) async {
    if (_disposed) {
      return;
    }
    if (result.isFailure) {
      final failure = result.failure!;
      if (failure is SessionExpiredFailure) {
        ref.read(authControllerProvider.notifier).refreshSession();
      }
      state = state.copyWith(
        isLiveListening: false,
        liveErrorMessage: failure.message.trim().isEmpty
            ? 'Live handoff updates disconnected.'
            : failure.message,
      );
      _scheduleEventReconnect();
      return;
    }

    final event = result.data!;
    final eventId = event.eventId?.trim();
    if (eventId != null && eventId.isNotEmpty) {
      _lastEventId = eventId;
    }
    state = state.copyWith(isLiveListening: true, clearLiveError: true);
    await _handleHandoffEvent(event);
  }

  Future<void> _handleHandoffEvent(HumanHandoffEventEntity event) async {
    if (event.tenantId.trim().isNotEmpty &&
        event.tenantId != state.selectedTenantId) {
      return;
    }

    if (event.updatesSession) {
      await loadSessions(refreshTranscript: false);
    }

    if (event.deliveryError?.trim().isNotEmpty ?? false) {
      if (event.sessionId == state.selectedSessionId) {
        state = state.copyWith(lastDeliveryError: event.deliveryError);
      }
    }

    final selectedSessionId = state.selectedSessionId;
    if (!event.appendsTranscript ||
        selectedSessionId == null ||
        event.sessionId != selectedSessionId) {
      return;
    }

    final eventSequenceNo = event.sequenceNo;
    final latestSequenceNo = state.latestTranscriptSequenceNo;
    if (eventSequenceNo != null &&
        latestSequenceNo != null &&
        eventSequenceNo <= latestSequenceNo) {
      return;
    }
    await loadTranscript(incremental: latestSequenceNo != null);
  }

  void _applyFailure(Failure failure, {required String fallback}) {
    if (failure is SessionExpiredFailure) {
      ref.read(authControllerProvider.notifier).refreshSession();
    }
    final message = failure.message.trim().isEmpty ? fallback : failure.message;
    state = state.copyWith(errorMessage: message);
  }

  String _nextMessageId() {
    _messageCounter += 1;
    final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    return 'ui-human-$micros-$_messageCounter';
  }

  List<HumanHandoffTranscriptItemEntity> _mergeTranscriptItems(
    List<HumanHandoffTranscriptItemEntity> existing,
    List<HumanHandoffTranscriptItemEntity> incoming,
  ) {
    final bySequenceNo = <int, HumanHandoffTranscriptItemEntity>{
      for (final item in existing) item.sequenceNo: item,
      for (final item in incoming) item.sequenceNo: item,
    };
    final merged = bySequenceNo.values.toList(growable: false)
      ..sort((a, b) => a.sequenceNo.compareTo(b.sequenceNo));
    return merged;
  }

  int? _latestSequenceNo(List<HumanHandoffTranscriptItemEntity> items) {
    if (items.isEmpty) {
      return null;
    }
    return items
        .map((item) => item.sequenceNo)
        .reduce((value, element) => value > element ? value : element);
  }

  @override
  void dispose() {
    _disposed = true;
    _eventReconnectTimer?.cancel();
    _eventSubscription?.cancel();
    super.dispose();
  }
}
