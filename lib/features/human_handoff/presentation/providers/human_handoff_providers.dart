// coverage:ignore-file
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/human_handoff/application/dto/human_handoff_inputs.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_session_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_tenant_option_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_transcript_item_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/repositories/human_handoff_repository.dart';
import 'package:mugen_ui/features/human_handoff/infrastructure/repositories/human_handoff_repository_impl.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';

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
    this.selectedTenantId,
    this.selectedSessionId,
    this.pendingReplyMessageId,
    this.lastDeliveryError,
    this.errorMessage,
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
  final String? selectedTenantId;
  final String? selectedSessionId;
  final String? pendingReplyMessageId;
  final String? lastDeliveryError;
  final String? errorMessage;

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
    String? selectedTenantId,
    String? selectedSessionId,
    String? pendingReplyMessageId,
    String? lastDeliveryError,
    String? errorMessage,
    bool clearSelectedTenant = false,
    bool clearSelectedSession = false,
    bool clearPendingReplyMessage = false,
    bool clearLastDeliveryError = false,
    bool clearError = false,
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
    );
  }
}

final humanHandoffRepositoryProvider = Provider<HumanHandoffRepository>((ref) {
  return HumanHandoffRepositoryImpl(
    appConfig: ref.watch(appConfigProvider),
    authenticatedHttpClient: ref.watch(authenticatedHttpClientProvider),
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
        ),
      );

  final Ref ref;
  int _messageCounter = 0;

  Future<void> loadInitialData() async {
    await loadTenants();
    if (state.selectedTenantId != null) {
      await loadSessions();
    }
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
      clearSelectedTenant: tenants.isEmpty,
      clearSelectedSession: tenants.isEmpty,
      clearError: true,
    );
  }

  Future<void> loadSessions() async {
    final tenantId = state.selectedTenantId;
    if (tenantId == null || tenantId.isEmpty) {
      state = state.copyWith(
        sessions: const <HumanHandoffSessionEntity>[],
        transcript: const <HumanHandoffTranscriptItemEntity>[],
        total: 0,
        clearSelectedSession: true,
      );
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
      clearSelectedSession: selectedSessionId == null,
      clearError: true,
    );

    if (selectedSessionId != null) {
      await loadTranscript();
    }
  }

  Future<void> loadTranscript() async {
    final tenantId = state.selectedTenantId;
    final sessionId = state.selectedSessionId;
    if (tenantId == null ||
        tenantId.isEmpty ||
        sessionId == null ||
        sessionId.isEmpty) {
      state = state.copyWith(
        transcript: const <HumanHandoffTranscriptItemEntity>[],
      );
      return;
    }

    state = state.copyWith(isLoadingTranscript: true, clearError: true);
    final result = await ref
        .read(humanHandoffRepositoryProvider)
        .listTranscript(
          HumanHandoffTranscriptQuery(tenantId: tenantId, sessionId: sessionId),
        );
    if (result.isFailure) {
      _applyFailure(result.failure!, fallback: 'Could not load transcript.');
      state = state.copyWith(isLoadingTranscript: false);
      return;
    }

    state = state.copyWith(
      transcript: result.data ?? const <HumanHandoffTranscriptItemEntity>[],
      isLoadingTranscript: false,
      clearError: true,
    );
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
    );
    await loadSessions();
  }

  Future<void> selectSession(String sessionId) async {
    final normalized = sessionId.trim();
    if (normalized.isEmpty || normalized == state.selectedSessionId) {
      return;
    }
    state = state.copyWith(
      selectedSessionId: normalized,
      transcript: const <HumanHandoffTranscriptItemEntity>[],
      clearLastDeliveryError: true,
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
    await loadSessions();
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
}
