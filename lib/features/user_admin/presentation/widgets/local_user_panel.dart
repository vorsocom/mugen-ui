import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/user_admin/application/dto/edit_user_roles_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/update_user_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_registration_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_reset_password_admin_input.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_session_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_entity.dart';
import 'package:mugen_ui/features/user_admin/presentation/providers/user_admin_providers.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

class LocalUserPanel extends ConsumerStatefulWidget {
  const LocalUserPanel({super.key}); // coverage:ignore-line

  @override
  ConsumerState<LocalUserPanel> createState() => _LocalUserPanelState();
}

class _LocalUserPanelState extends ConsumerState<LocalUserPanel> {
  Timer? _searchDebounce;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 300);
  static const double _tableMinWidth = 940;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      ref.read(userAdminControllerProvider.notifier).loadUsers();
      ref.read(userAdminControllerProvider.notifier).loadRoles();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _showRegisterDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const Dialog(child: _RegisterUserForm()),
    );
  }

  Future<void> _showEditUserDialog(UserEntity user) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(child: _EditUserForm(user: user)),
    );
  }

  Future<void> _showResetPasswordDialog(UserEntity user) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(child: _ResetPasswordAdminForm(user: user)),
    );
  }

  Future<void> _showEditRolesDialog(UserEntity user) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: AppUiPalette.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppUiPalette.border),
        ),
        child: _EditRolesForm(user: user),
      ),
    );
  }

  Future<void> _showSessionsDialog(UserEntity user) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: AppUiPalette.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppUiPalette.border),
        ),
        child: _UserSessionsDialog(user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userAdminControllerProvider);
    final controller = ref.read(userAdminControllerProvider.notifier);
    final snackBar = ref.read(snackBarDispatcherProvider);
    final navigator = ref.read(appNavigatorProvider);
    final theme = Theme.of(context);

    Future<void> handleEnableUserAccount(String userId) async {
      final success = await controller.enableUser(userId);
      if (success) {
        snackBar.show(navigator, 'User account successfully enabled.');
      } else {
        snackBar.show(
          navigator,
          'User account could not be enabled. Please try again.',
        );
      }
    }

    Future<void> handleDisableUserAccount(String userId) async {
      final success = await controller.disableUser(userId);
      if (success) {
        snackBar.show(navigator, 'User account successfully disabled.');
      } else {
        snackBar.show(
          navigator,
          'User account could not be disabled. Please try again.',
        );
      }
    }

    Future<void> handleDeleteUser(String userId) async {
      final success = await controller.deleteUser(userId);
      if (success) {
        snackBar.show(navigator, 'User account successfully deleted.');
      } else {
        snackBar.show(
          navigator,
          'User account could not be deleted. Please try again.',
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _showRegisterDialog,
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppUiPalette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppUiPalette.border, width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppUiPalette.surfaceStrong,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_add,
                          size: 18,
                          color: AppUiPalette.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'New User',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppUiPalette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          decoration: InputDecoration(
            hintText: 'Search users...',
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0),
            suffixIcon: const Icon(Icons.person_search_outlined),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: const BorderSide(
                color: AppUiPalette.border,
                width: 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: const BorderSide(
                color: AppUiPalette.borderStrong,
                width: 1.0,
              ),
            ),
          ),
          onChanged: (value) {
            _searchDebounce?.cancel();
            _searchDebounce = Timer(_searchDebounceDuration, () async {
              final term = value.trim();
              controller.setSearchTerm(term);
              await controller.loadUsers();
            });
          },
        ),
        const SizedBox(height: 8),
        if (state.isLoadingUsers)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(),
          ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppUiPalette.surface,
              border: Border.all(color: AppUiPalette.border, width: 1.0),
              borderRadius: BorderRadius.circular(14.0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : _tableMinWidth;
                  final tableWidth = math.max(availableWidth, _tableMinWidth);
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStatePropertyAll<Color?>(
                            AppUiPalette.surfaceMuted,
                          ),
                          headingTextStyle: theme.textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppUiPalette.textPrimary,
                              ),
                          dataTextStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: AppUiPalette.textPrimary,
                          ),
                          dataRowMinHeight: 44,
                          dataRowMaxHeight: 50,
                          columnSpacing: 22,
                          horizontalMargin: 16,
                          dividerThickness: 1.0,
                          columns: const [
                            DataColumn(label: Text('Username')),
                            DataColumn(label: Text('First Name')),
                            DataColumn(label: Text('Last Name')),
                            DataColumn(label: Text('Date Created')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: List<DataRow>.generate(state.pageSize, (index) {
                            final rowBackground = index.isEven
                                ? Colors.white
                                : AppUiPalette.surface;
                            if (state.total == 0 ||
                                index >= state.users.length) {
                              return DataRow(
                                color: WidgetStatePropertyAll<Color?>(
                                  rowBackground,
                                ),
                                cells: const <DataCell>[
                                  DataCell(SizedBox.shrink()),
                                  DataCell(SizedBox.shrink()),
                                  DataCell(SizedBox.shrink()),
                                  DataCell(SizedBox.shrink()),
                                  DataCell(SizedBox.shrink()),
                                ],
                              );
                            }

                            final user = state.users[index];
                            return DataRow(
                              color: WidgetStatePropertyAll<Color?>(
                                rowBackground,
                              ),
                              cells: [
                                DataCell(Text(user.userName)),
                                DataCell(Text(user.person.firstName)),
                                DataCell(Text(user.person.lastName)),
                                DataCell(
                                  Text(
                                    '${user.dateCreated.toUtc()}'
                                        .split('.')
                                        .first,
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _LocalUserActionIcon(
                                        icon: Icons.edit_outlined,
                                        onPressed: () =>
                                            _showEditUserDialog(user),
                                        tooltip: 'Edit Details',
                                      ),
                                      const SizedBox(width: 4),
                                      _LocalUserActionIcon(
                                        icon: Icons.work_outline_outlined,
                                        onPressed: () =>
                                            _showEditRolesDialog(user),
                                        tooltip: 'Edit Roles',
                                      ),
                                      const SizedBox(width: 4),
                                      _LocalUserActionIcon(
                                        icon: Icons.password_outlined,
                                        onPressed: () =>
                                            _showResetPasswordDialog(user),
                                        tooltip: 'Reset Password',
                                      ),
                                      const SizedBox(width: 4),
                                      _LocalUserActionIcon(
                                        icon: Icons.history_toggle_off_outlined,
                                        onPressed: () =>
                                            _showSessionsDialog(user),
                                        tooltip: 'Sessions',
                                      ),
                                      const SizedBox(width: 4),
                                      _LocalUserActionIcon(
                                        icon: user.isLocked
                                            ? Icons.person_outline_outlined
                                            : Icons.person_off_outlined,
                                        iconColor: user.isLocked
                                            ? Colors.green.shade700
                                            : Colors.red.shade700,
                                        onPressed: () async {
                                          final confirmed =
                                              await showAppConfirmationDialog(
                                                context: context,
                                                title: 'Confirmation Required',
                                                message: user.isLocked
                                                    ? 'Enabling this account will allow the user to log in and perform permitted actions.'
                                                    : 'Disabling this account will prevent the user from logging in and performing any actions.',
                                                confirmLabel: 'Continue',
                                                icon: user.isLocked
                                                    ? Icons
                                                          .person_outline_outlined
                                                    : Icons.person_off_outlined,
                                              );

                                          if (confirmed != true) {
                                            return;
                                          }

                                          if (user.isLocked) {
                                            await handleEnableUserAccount(
                                              user.id,
                                            );
                                          } else {
                                            await handleDisableUserAccount(
                                              user.id,
                                            );
                                          }
                                        },
                                        tooltip: user.isLocked
                                            ? 'Enable Account'
                                            : 'Disable Account',
                                      ),
                                      const SizedBox(width: 4),
                                      _LocalUserActionIcon(
                                        icon: Icons.delete_outline,
                                        iconColor: Colors.red.shade700,
                                        onPressed: () async {
                                          final confirmed =
                                              await showAppConfirmationDialog(
                                                context: context,
                                                title: 'Confirmation Required',
                                                message:
                                                    'Deleting this user will immediately disable access and remove the account.',
                                                confirmLabel: 'Delete User',
                                                icon: Icons.delete_outline,
                                              );

                                          if (confirmed != true) {
                                            return;
                                          }

                                          await handleDeleteUser(user.id);
                                        },
                                        tooltip: 'Delete User',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : _tableMinWidth;
            final paginatorWidth = math.max(availableWidth, _tableMinWidth);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: paginatorWidth,
                child: _Paginator(
                  rowsPerPage: state.pageSize,
                  currentPage: state.page,
                  pages: state.pages,
                  count: state.total,
                  items: state.users.length,
                  onRowsPerPageChanged: (value) async {
                    controller.setRowsPerPage(value);
                    await controller.loadUsers();
                  },
                  onFirstPagePressed: () async {
                    controller.setPage(1);
                    await controller.loadUsers();
                  },
                  onPreviousPagePressed: () async {
                    controller.setPage(state.page - 1);
                    await controller.loadUsers();
                  },
                  onLastPagePressed: () async {
                    controller.setPage(state.pages);
                    await controller.loadUsers();
                  },
                  onNextPagePressed: () async {
                    controller.setPage(state.page + 1);
                    await controller.loadUsers();
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Paginator extends StatelessWidget {
  const _Paginator({
    required this.rowsPerPage,
    required this.currentPage,
    required this.pages,
    required this.count,
    required this.items,
    required this.onRowsPerPageChanged,
    required this.onFirstPagePressed,
    required this.onPreviousPagePressed,
    required this.onLastPagePressed,
    required this.onNextPagePressed,
  });

  final int rowsPerPage;
  final int currentPage;
  final int pages;
  final int count;
  final int items;
  final ValueChanged<int> onRowsPerPageChanged;
  final VoidCallback onFirstPagePressed;
  final VoidCallback onPreviousPagePressed;
  final VoidCallback onLastPagePressed;
  final VoidCallback onNextPagePressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedPages = pages <= 0 ? 1 : pages;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppUiPalette.surface,
          border: Border.all(color: AppUiPalette.border, width: 1.0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              'Rows',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppUiPalette.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppUiPalette.border, width: 1.0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: rowsPerPage,
                  icon: const Icon(Icons.expand_more, size: 18),
                  items: const [15, 25, 50]
                      .map(
                        (value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value'),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      onRowsPerPageChanged(value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              '$items of $count',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppUiPalette.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            _PaginatorIconButton(
              icon: Icons.first_page,
              tooltip: 'First page',
              onPressed: currentPage <= 1 ? null : onFirstPagePressed,
            ),
            const SizedBox(width: 4),
            _PaginatorIconButton(
              icon: Icons.chevron_left,
              tooltip: 'Previous page',
              onPressed: currentPage <= 1 ? null : onPreviousPagePressed,
            ),
            const SizedBox(width: 8),
            Text(
              '$currentPage / $resolvedPages',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            _PaginatorIconButton(
              icon: Icons.chevron_right,
              tooltip: 'Next page',
              onPressed: currentPage >= resolvedPages
                  ? null
                  : onNextPagePressed,
            ),
            const SizedBox(width: 4),
            _PaginatorIconButton(
              icon: Icons.last_page,
              tooltip: 'Last page',
              onPressed: currentPage >= resolvedPages
                  ? null
                  : onLastPagePressed,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginatorIconButton extends StatelessWidget {
  const _PaginatorIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Ink(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isEnabled
                  ? AppUiPalette.surfaceStrong
                  : AppUiPalette.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: isEnabled
                  ? AppUiPalette.textPrimary
                  : AppUiPalette.borderStrong,
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalUserActionIcon extends StatelessWidget {
  const _LocalUserActionIcon({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Ink(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppUiPalette.surfaceStrong,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: iconColor ?? AppUiPalette.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _UserSessionsDialog extends ConsumerStatefulWidget {
  const _UserSessionsDialog({required this.user});

  final UserEntity user;

  @override
  ConsumerState<_UserSessionsDialog> createState() =>
      _UserSessionsDialogState();
}

class _UserSessionsDialogState extends ConsumerState<_UserSessionsDialog> {
  bool _loading = true;
  bool _revoking = false;
  String? _error;
  List<UserSessionEntity> _sessions = const <UserSessionEntity>[];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadSessions);
  }

  Future<void> _loadSessions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref
        .read(userAdminControllerProvider.notifier)
        .fetchUserSessions(widget.user.id);

    if (!mounted) {
      return;
    }

    if (result.isFailure) {
      setState(() {
        _loading = false;
        _sessions = const <UserSessionEntity>[];
        _error = result.failure?.message ?? 'Could not load sessions.';
      });
      return;
    }

    setState(() {
      _loading = false;
      _sessions = result.data!;
      _error = null;
    });
  }

  Future<void> _revokeSession(UserSessionEntity session) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Confirmation Required',
      message:
          'Revoking this session will force the client to authenticate again.',
      confirmLabel: 'Revoke Session',
      icon: Icons.block_outlined,
    );
    if (confirmed != true) {
      return;
    }

    setState(() {
      _revoking = true;
    });

    final success = await ref
        .read(userAdminControllerProvider.notifier)
        .revokeUserSession(session.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _revoking = false;
    });

    final snackBar = ref.read(snackBarDispatcherProvider);
    final navigator = ref.read(appNavigatorProvider);
    if (!success) {
      snackBar.show(
        navigator,
        'Session could not be revoked. Please try again.',
      );
      return;
    }

    snackBar.show(navigator, 'Session revoked successfully.');
    await _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 760,
      child: AppFormPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sessions - ${widget.user.userName}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh Sessions',
                  onPressed: _loading || _revoking ? null : _loadSessions,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppUiPalette.textSecondary,
                ),
              ),
            ],
            if (!_loading && _error == null) ...[
              if (_sessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'No active sessions found for this user.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppUiPalette.textSecondary,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    itemCount: _sessions.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: AppUiPalette.border),
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        title: Text('Session ${_shortId(session.id)}'),
                        subtitle: Text(
                          'Created: ${session.dateCreated.toUtc().toString().split('.').first}\n'
                          'Expires: ${session.expiresAt.toUtc().toString().split('.').first}',
                        ),
                        isThreeLine: true,
                        trailing: TextButton.icon(
                          onPressed: _revoking
                              ? null
                              : () => _revokeSession(session),
                          icon: const Icon(Icons.block_outlined, size: 16),
                          label: const Text('Revoke'),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _shortId(String value) {
    if (value.length <= 12) {
      return value;
    }

    return '${value.substring(0, 8)}...${value.substring(value.length - 4)}';
  }
}

class _RegisterUserForm extends ConsumerStatefulWidget {
  const _RegisterUserForm();

  @override
  ConsumerState<_RegisterUserForm> createState() => _RegisterUserFormState();
}

class _RegisterUserFormState extends ConsumerState<_RegisterUserForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _userNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final success = await ref
        .read(userAdminControllerProvider.notifier)
        .registerUser(
          UserRegistrationInput(
            firstName: _firstNameController.text,
            lastName: _lastNameController.text,
            userName: _userNameController.text,
            email: _emailController.text,
            password: _passwordController.text,
          ),
        );

    setState(() {
      _saving = false;
    });

    if (!mounted) {
      return;
    }

    final snackBar = ref.read(snackBarDispatcherProvider);
    final navigator = ref.read(appNavigatorProvider);

    if (success) {
      snackBar.show(navigator, 'User account successfully added.');
      Navigator.of(context).pop();
      return;
    }

    snackBar.show(
      navigator,
      'User account could not be added. Please try again.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 520,
      child: AppFormPanel(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add New User',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _firstNameController,
                decoration: appFormInputDecoration(labelText: 'First Name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameController,
                decoration: appFormInputDecoration(labelText: 'Last Name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _userNameController,
                decoration: appFormInputDecoration(labelText: 'Username'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: appFormInputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Field cannot be empty.';
                  }
                  final regex = RegExp(
                    "[a-z0-9!#\\\$%&'*+/=?^_`{|}~-]+(?:\\.[a-z0-9!#\\\$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?",
                  );
                  if (!regex.hasMatch(value)) {
                    return 'Email address must be valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: appFormInputDecoration(labelText: 'Password'),
                validator: _required,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add User'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.isEmpty) {
      return 'Field cannot be empty.';
    }
    return null;
  }
}

class _EditUserForm extends ConsumerStatefulWidget {
  const _EditUserForm({required this.user});

  final UserEntity user;

  @override
  ConsumerState<_EditUserForm> createState() => _EditUserFormState();
}

class _EditUserFormState extends ConsumerState<_EditUserForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.user.person.firstName,
    );
    _lastNameController = TextEditingController(
      text: widget.user.person.lastName,
    );
    _emailController = TextEditingController(text: widget.user.email);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final success = await ref
        .read(userAdminControllerProvider.notifier)
        .updateUser(
          UpdateUserInput(
            userId: widget.user.id,
            personId: widget.user.person.id.isEmpty
                ? widget.user.personRef
                : widget.user.person.id,
            firstName: _firstNameController.text,
            lastName: _lastNameController.text,
            email: _emailController.text,
          ),
        );

    setState(() {
      _saving = false;
    });

    if (!mounted) {
      return;
    }

    final snackBar = ref.read(snackBarDispatcherProvider);
    final navigator = ref.read(appNavigatorProvider);

    if (success) {
      snackBar.show(navigator, 'User details updated successfully.');
      Navigator.of(context).pop();
      return;
    }

    snackBar.show(navigator, 'User details update failed. Please try again.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 520,
      child: AppFormPanel(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit User Details',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _firstNameController,
                decoration: appFormInputDecoration(labelText: 'First name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameController,
                decoration: appFormInputDecoration(labelText: 'Last name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: appFormInputDecoration(labelText: 'Email'),
                validator: _required,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.isEmpty) {
      return 'Field cannot be empty.';
    }
    return null;
  }
}

class _ResetPasswordAdminForm extends ConsumerStatefulWidget {
  const _ResetPasswordAdminForm({required this.user});

  final UserEntity user;

  @override
  ConsumerState<_ResetPasswordAdminForm> createState() =>
      _ResetPasswordAdminFormState();
}

class _ResetPasswordAdminFormState
    extends ConsumerState<_ResetPasswordAdminForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final success = await ref
        .read(userAdminControllerProvider.notifier)
        .resetUserPasswordAdmin(
          UserResetPasswordAdminInput(
            userId: widget.user.id,
            newPassword: _newPasswordController.text,
            confirmNewPassword: _confirmPasswordController.text,
            rowVersion: widget.user.rowVersion,
          ),
        );

    setState(() {
      _saving = false;
    });

    if (!mounted) {
      return;
    }

    final snackBar = ref.read(snackBarDispatcherProvider);
    final navigator = ref.read(appNavigatorProvider);

    if (success) {
      snackBar.show(navigator, 'Password reset successful.');
      Navigator.of(context).pop();
      return;
    }

    snackBar.show(navigator, 'Password reset failed. Please try again.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 520,
      child: AppFormPanel(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Reset User Password - ${widget.user.userName}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: appFormInputDecoration(labelText: 'New password'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: appFormInputDecoration(
                  labelText: 'Confirm new password',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Field cannot be empty.';
                  }

                  if (value != _newPasswordController.text) {
                    return 'Passwords must match.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Reset Password'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.isEmpty) {
      return 'Field cannot be empty.';
    }

    return null;
  }
}

class _EditRolesForm extends ConsumerStatefulWidget {
  const _EditRolesForm({required this.user});

  final UserEntity user;

  @override
  ConsumerState<_EditRolesForm> createState() => _EditRolesFormState();
}

class _EditRolesFormState extends ConsumerState<_EditRolesForm> {
  late Set<String> _selectedRoleNames;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final roles = ref.read(userAdminControllerProvider).roles;
    _selectedRoleNames = <String>{};
    for (final role in roles) {
      if (widget.user.roles.contains(role.id)) {
        _selectedRoleNames.add(role.name);
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
    });

    final success = await ref
        .read(userAdminControllerProvider.notifier)
        .editUserRoles(
          EditUserRolesInput(
            userId: widget.user.id,
            roles: _selectedRoleNames.toList(growable: false),
          ),
        );

    setState(() {
      _saving = false;
    });

    if (!mounted) {
      return;
    }

    final snackBar = ref.read(snackBarDispatcherProvider);
    final navigator = ref.read(appNavigatorProvider);

    if (success) {
      snackBar.show(navigator, 'User roles update successful.');
      Navigator.of(context).pop();
      return;
    }

    snackBar.show(navigator, 'User roles update failed. Please try again.');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userAdminControllerProvider);
    final theme = Theme.of(context);

    return SizedBox(
      width: 620,
      child: AppFormPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit User Roles - ${widget.user.userName}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (state.isLoadingRoles) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: Container(
                decoration: BoxDecoration(
                  color: AppUiPalette.surface,
                  border: Border.all(color: AppUiPalette.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStatePropertyAll<Color?>(
                        AppUiPalette.surfaceMuted,
                      ),
                      columns: const [
                        DataColumn(label: Text('Role')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: [
                        for (final role in state.roles)
                          DataRow(
                            cells: [
                              DataCell(Text(role.displayName)),
                              DataCell(
                                Checkbox(
                                  value: _selectedRoleNames.contains(role.name),
                                  onChanged: state.isLoadingRoles
                                      ? null
                                      : (value) {
                                          setState(() {
                                            if (value == true) {
                                              _selectedRoleNames.add(role.name);
                                            } else {
                                              _selectedRoleNames.remove(
                                                role.name,
                                              );
                                            }
                                          });
                                        },
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving || state.isLoadingRoles ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Roles'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
