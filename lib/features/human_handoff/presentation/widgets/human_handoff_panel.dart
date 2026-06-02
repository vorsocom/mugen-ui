// coverage:ignore-file
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_session_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_transcript_item_entity.dart';
import 'package:mugen_ui/features/human_handoff/presentation/providers/human_handoff_providers.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

const Key _platformFilterKey = Key('human-handoff-platform-filter');
const Key _serviceRouteFilterKey = Key('human-handoff-service-route-filter');
const Key _ownerFilterKey = Key('human-handoff-owner-filter');
const Key _refreshButtonKey = Key('human-handoff-refresh-button');
const Key _replyFieldKey = Key('human-handoff-reply-field');
const Key _sendReplyButtonKey = Key('human-handoff-send-reply-button');
const Key _releaseButtonKey = Key('human-handoff-release-button');
const Key _releaseReasonFieldKey = Key('human-handoff-release-reason-field');
const Key _confirmReleaseButtonKey = Key('human-handoff-confirm-release');

class HumanHandoffPanel extends ConsumerStatefulWidget {
  const HumanHandoffPanel({super.key}); // coverage:ignore-line

  @override
  ConsumerState<HumanHandoffPanel> createState() => _HumanHandoffPanelState();
}

class _HumanHandoffPanelState extends ConsumerState<HumanHandoffPanel> {
  final TextEditingController _platformController = TextEditingController();
  final TextEditingController _serviceRouteController = TextEditingController();
  final TextEditingController _ownerController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(humanHandoffControllerProvider.notifier).loadInitialData();
    });
  }

  @override
  void dispose() {
    _platformController.dispose();
    _serviceRouteController.dispose();
    _ownerController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(humanHandoffControllerProvider);
    _syncReplyController(state.draftText);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 940;
        final queue = _QueuePane(
          state: state,
          platformController: _platformController,
          serviceRouteController: _serviceRouteController,
          ownerController: _ownerController,
        );
        final detail = _DetailPane(
          state: state,
          replyController: _replyController,
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 360, child: queue),
              const SizedBox(height: 12),
              Expanded(child: detail),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 390, child: queue),
            const SizedBox(width: 12),
            Expanded(child: detail),
          ],
        );
      },
    );
  }

  void _syncReplyController(String draftText) {
    if (_replyController.text == draftText) {
      return;
    }
    _replyController.value = TextEditingValue(
      text: draftText,
      selection: TextSelection.collapsed(offset: draftText.length),
    );
  }
}

class _QueuePane extends ConsumerWidget {
  const _QueuePane({
    required this.state,
    required this.platformController,
    required this.serviceRouteController,
    required this.ownerController,
  });

  final HumanHandoffState state;
  final TextEditingController platformController;
  final TextEditingController serviceRouteController;
  final TextEditingController ownerController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(humanHandoffControllerProvider.notifier);
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey<String>(
                    'human-handoff-tenant-${state.selectedTenantId ?? ''}',
                  ),
                  initialValue: state.selectedTenantId,
                  isExpanded: true,
                  decoration: appFormInputDecoration(labelText: 'Tenant'),
                  items: state.tenants
                      .map(
                        (tenant) => DropdownMenuItem<String>(
                          value: tenant.id,
                          child: Text(
                            tenant.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: state.isLoadingTenants
                      ? null
                      : (value) => controller.selectTenant(value),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                key: _refreshButtonKey,
                tooltip: 'Refresh handoff sessions',
                onPressed: state.isLoadingSessions
                    ? null
                    : () => controller.loadSessions(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey<String>(
                    'human-handoff-status-${state.statusFilter}',
                  ),
                  initialValue: state.statusFilter,
                  isExpanded: true,
                  decoration: appFormInputDecoration(labelText: 'Status'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'active',
                      child: Text('Active'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'inactive',
                      child: Text('Inactive'),
                    ),
                    DropdownMenuItem<String>(value: 'all', child: Text('All')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      controller.setStatusFilter(value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: _platformFilterKey,
                  controller: platformController,
                  decoration: appFormInputDecoration(labelText: 'Platform'),
                  textInputAction: TextInputAction.search,
                  onSubmitted: controller.setPlatformFilter,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: _serviceRouteFilterKey,
                  controller: serviceRouteController,
                  decoration: appFormInputDecoration(
                    labelText: 'Service Route',
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: controller.setServiceRouteFilter,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: _ownerFilterKey,
                  controller: ownerController,
                  decoration: appFormInputDecoration(labelText: 'Owner'),
                  textInputAction: TextInputAction.search,
                  onSubmitted: controller.setOwnerFilter,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _LiveStatusLine(state: state),
          const SizedBox(height: 10),
          if (state.errorMessage != null) ...[
            AppErrorAlert(message: state.errorMessage!),
            const SizedBox(height: 10),
          ],
          Expanded(child: _buildSessionList(context, ref)),
          const SizedBox(height: 8),
          _Pager(state: state),
        ],
      ),
    );
  }

  Widget _buildSessionList(BuildContext context, WidgetRef ref) {
    if (state.isLoadingSessions && state.sessions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.selectedTenantId == null) {
      return const Center(child: Text('Select a tenant.'));
    }
    if (state.sessions.isEmpty) {
      return const Center(child: Text('No handoff sessions found.'));
    }

    return ListView.separated(
      itemCount: state.sessions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final session = state.sessions[index];
        final selected = state.selectedSessionId == session.id;
        return _SessionTile(session: session, selected: selected);
      },
    );
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session, required this.selected});

  final HumanHandoffSessionEntity session;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statusColor = session.hasDeliveryFailure
        ? AppUiPalette.danger
        : session.isActive
        ? Colors.green.shade700
        : AppUiPalette.textMuted;
    return Material(
      color: selected ? AppUiPalette.surfaceStrong : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => ref
            .read(humanHandoffControllerProvider.notifier)
            .selectSession(session.id),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppUiPalette.textMuted : AppUiPalette.border,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.platform.isEmpty ? 'unknown' : session.platform,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (session.hasNewUserActivity) ...[
                    const _StatusPill(
                      label: 'New user',
                      color: AppUiPalette.warning,
                    ),
                    const SizedBox(width: 6),
                  ],
                  _StatusPill(label: session.status, color: statusColor),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                session.scopeKey.isEmpty ? session.id : session.scopeKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppUiPalette.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 2,
                children: [
                  _TinyMeta(label: 'Room', value: session.roomId),
                  _TinyMeta(label: 'Sender', value: session.senderId),
                  _TinyMeta(label: 'Route', value: session.serviceRouteKey),
                  _TinyMeta(
                    label: 'Last user',
                    value: _formatCompactDateTime(session.lastUserMessageAt),
                  ),
                ],
              ),
              if (session.lastDeliveryError?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 6),
                Text(
                  session.lastDeliveryError!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppUiPalette.danger,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailPane extends ConsumerWidget {
  const _DetailPane({required this.state, required this.replyController});

  final HumanHandoffState state;
  final TextEditingController replyController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = state.selectedSession;
    if (session == null) {
      return const _Surface(child: Center(child: Text('No session selected.')));
    }

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SessionHeader(session: session),
          const SizedBox(height: 10),
          if (state.lastDeliveryError != null) ...[
            AppErrorAlert(message: state.lastDeliveryError!),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: state.isLoadingTranscript && state.transcript.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _TranscriptList(items: state.transcript),
          ),
          const SizedBox(height: 10),
          _ReplyComposer(state: state, replyController: replyController),
        ],
      ),
    );
  }
}

class _SessionHeader extends ConsumerWidget {
  const _SessionHeader({required this.session});

  final HumanHandoffSessionEntity session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppUiPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppUiPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.scopeKey.isEmpty ? session.id : session.scopeKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                key: _releaseButtonKey,
                onPressed: session.isActive
                    ? () => _showReleaseDialog(context, ref)
                    : null,
                icon: const Icon(Icons.logout_outlined),
                label: const Text('Release'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(label: 'Status', value: session.status),
              _InfoChip(label: 'Platform', value: session.platform),
              _InfoChip(label: 'Room', value: session.roomId),
              _InfoChip(label: 'Sender', value: session.senderId),
              _InfoChip(label: 'Conversation', value: session.conversationId),
              _InfoChip(label: 'Route', value: session.serviceRouteKey),
              _InfoChip(label: 'Owner', value: session.ownerUserId),
              _InfoChip(label: 'Delivery', value: session.lastDeliveryStatus),
              _InfoChip(
                label: 'Last User',
                value: _formatCompactDateTime(session.lastUserMessageAt),
              ),
              _InfoChip(
                label: 'Transcript',
                value: session.lastTranscriptSequenceNo?.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showReleaseDialog(BuildContext context, WidgetRef ref) async {
    final confirmedReason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReleaseHandoffDialog(),
    );
    if (confirmedReason == null || !context.mounted) {
      return;
    }
    await ref
        .read(humanHandoffControllerProvider.notifier)
        .releaseSelected(reason: confirmedReason);
  }
}

class _ReleaseHandoffDialog extends StatefulWidget {
  const _ReleaseHandoffDialog();

  @override
  State<_ReleaseHandoffDialog> createState() => _ReleaseHandoffDialogState();
}

class _ReleaseHandoffDialogState extends State<_ReleaseHandoffDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: AppUiPalette.surfaceMuted,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppUiPalette.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: AppFormPanel(
          margin: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Release handoff',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                key: _releaseReasonFieldKey,
                controller: _reasonController,
                minLines: 3,
                maxLines: 5,
                decoration: appFormInputDecoration(labelText: 'Reason'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: _confirmReleaseButtonKey,
                    onPressed: () =>
                        Navigator.of(context).pop(_reasonController.text),
                    icon: const Icon(Icons.logout_outlined),
                    label: const Text('Release'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TranscriptList extends StatelessWidget {
  const _TranscriptList({required this.items});

  final List<HumanHandoffTranscriptItemEntity> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No transcript items found.'));
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _TranscriptBubble(item: items[index]);
      },
    );
  }
}

class _TranscriptBubble extends StatelessWidget {
  const _TranscriptBubble({required this.item});

  final HumanHandoffTranscriptItemEntity item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = item.isUser;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = isUser
        ? AppUiPalette.surfaceStrong
        : AppUiPalette.surfaceMuted;
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppUiPalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _roleLabel(item),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppUiPalette.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                _formatContent(item.content),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                '#${item.sequenceNo}  ${_formatDateTime(item.occurredAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppUiPalette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyComposer extends ConsumerWidget {
  const _ReplyComposer({required this.state, required this.replyController});

  final HumanHandoffState state;
  final TextEditingController replyController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = state.selectedSession;
    final active = session?.isActive ?? false;
    final controller = ref.read(humanHandoffControllerProvider.notifier);
    final submitLabel = state.lastDeliveryError == null ? 'Send' : 'Retry';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: _replyFieldKey,
          controller: replyController,
          minLines: 3,
          maxLines: 6,
          enabled: active && !state.isReplying && !state.isReleasing,
          decoration: appFormInputDecoration(
            labelText: active ? 'Human Reply' : 'Composer disabled',
          ),
          onChanged: controller.updateDraft,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: state.isLoadingTranscript
                  ? null
                  : () => controller.loadTranscript(),
              icon: const Icon(Icons.sync),
              label: const Text('Transcript'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: _sendReplyButtonKey,
              onPressed: state.canReply ? () => controller.sendReply() : null,
              icon: state.isReplying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(submitLabel),
            ),
          ],
        ),
      ],
    );
  }
}

class _Pager extends ConsumerWidget {
  const _Pager({required this.state});

  final HumanHandoffState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(humanHandoffControllerProvider.notifier);
    return Row(
      children: [
        Text('${state.total} sessions'),
        const Spacer(),
        IconButton(
          tooltip: 'Previous page',
          onPressed: state.page <= 1
              ? null
              : () => controller.goToPage(state.page - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        Text('${state.page} / ${state.pages}'),
        IconButton(
          tooltip: 'Next page',
          onPressed: state.page >= state.pages
              ? null
              : () => controller.goToPage(state.page + 1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _LiveStatusLine extends StatelessWidget {
  const _LiveStatusLine({required this.state});

  final HumanHandoffState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = state.liveErrorMessage?.trim();
    final color = error != null && error.isNotEmpty
        ? AppUiPalette.warning
        : state.isLiveListening
        ? AppUiPalette.success
        : AppUiPalette.textMuted;
    final label = error != null && error.isNotEmpty
        ? 'Live updates paused'
        : state.isLiveListening
        ? 'Live updates on'
        : 'Live updates off';
    return Row(
      children: [
        Icon(Icons.circle, size: 9, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppUiPalette.surface,
        border: Border.all(color: AppUiPalette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.isEmpty ? '-' : label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TinyMeta extends StatelessWidget {
  const _TinyMeta({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      '$label: $text',
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppUiPalette.textSecondary),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text('$label: $text'),
      side: const BorderSide(color: AppUiPalette.border),
      backgroundColor: Colors.white,
    );
  }
}

String _roleLabel(HumanHandoffTranscriptItemEntity item) {
  if (item.isHumanReply) {
    return 'Human Reply';
  }
  if (item.isUser) {
    return 'User';
  }
  return item.role.isEmpty ? 'Event' : item.role;
}

String _formatContent(Object? content) {
  if (content == null) {
    return '';
  }
  if (content is String) {
    return content;
  }
  const encoder = JsonEncoder.withIndent('  ');
  try {
    return encoder.convert(content);
  } catch (_) {
    return content.toString();
  }
}

String _formatDateTime(DateTime? dateTime) {
  if (dateTime == null) {
    return '-';
  }
  return dateTime.toLocal().toString();
}

String? _formatCompactDateTime(DateTime? dateTime) {
  if (dateTime == null) {
    return null;
  }
  final local = dateTime.toLocal();
  final paddedMonth = local.month.toString().padLeft(2, '0');
  final paddedDay = local.day.toString().padLeft(2, '0');
  final paddedHour = local.hour.toString().padLeft(2, '0');
  final paddedMinute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$paddedMonth-$paddedDay $paddedHour:$paddedMinute';
}
