import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/user_admin/application/dto/update_user_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_registration_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_reset_password_admin_input.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_session_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_entity.dart';
import 'package:mugen_ui/features/user_admin/presentation/providers/user_admin_providers.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_field_help.dart';
import 'package:mugen_ui/shared/presentation/admin/admin_components.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

const double _localUserActionsColumnWidth = 176;
const double _userSessionsDialogMaxWidth = 760;
const double _userSessionsDialogMaxHeight = 760;
const double _userSessionsDialogInset = 24;

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

  Future<void> _showSessionsDialog(UserEntity user) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final mediaSize = MediaQuery.sizeOf(dialogContext);
        final maxWidth = math.min(
          _userSessionsDialogMaxWidth,
          math.max(0.0, mediaSize.width - (_userSessionsDialogInset * 2)),
        );
        final maxHeight = math.min(
          _userSessionsDialogMaxHeight,
          math.max(0.0, mediaSize.height - (_userSessionsDialogInset * 2)),
        );

        return Dialog(
          insetPadding: const EdgeInsets.all(_userSessionsDialogInset),
          backgroundColor: AppUiPalette.surfaceMuted,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppUiPalette.border),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: _UserSessionsDialog(user: user),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userAdminControllerProvider);
    final controller = ref.read(userAdminControllerProvider.notifier);
    final snackBar = ref.read(snackBarDispatcherProvider);
    final navigator = ref.read(appNavigatorProvider);

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
        AdminPageHeader(
          title: 'Local Users',
          subtitle:
              'Manage local accounts, credentials, sessions, and access state.',
          primaryAction: FilledButton.icon(
            key: const Key('local-users-new-user-button'),
            onPressed: _showRegisterDialog,
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('New User'),
          ),
        ),
        AdminToolbar(
          children: [
            SizedBox(
              width: 320,
              child: TextFormField(
                key: const Key('local-users-search-field'),
                initialValue: state.searchTerm,
                decoration: const InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: Icon(Icons.search),
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
            ),
            TextButton.icon(
              onPressed: () async {
                await controller.loadUsers();
                await controller.loadRoles();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppErrorAlert(message: state.errorMessage!),
          ),
        Expanded(
          child: AdminSurface(
            padding: EdgeInsets.zero,
            child: AdminDataGrid<UserEntity>(
              rows: state.users,
              columns: [
                AdminGridColumn<UserEntity>(
                  key: 'username',
                  label: 'Username',
                  flex: 2,
                  cell: (_, user) => AdminCellText(user.userName),
                ),
                AdminGridColumn<UserEntity>(
                  key: 'firstName',
                  label: 'First Name',
                  cell: (_, user) => AdminCellText(user.person.firstName),
                ),
                AdminGridColumn<UserEntity>(
                  key: 'lastName',
                  label: 'Last Name',
                  cell: (_, user) => AdminCellText(user.person.lastName),
                ),
                AdminGridColumn<UserEntity>(
                  key: 'dateCreated',
                  label: 'Date Created',
                  flex: 2,
                  cell: (_, user) =>
                      AdminCellText(_formatLocalUserDate(user.dateCreated)),
                ),
                AdminGridColumn<UserEntity>(
                  key: 'status',
                  label: 'Status',
                  cell: (_, user) => AdminStatusChip(
                    label: user.isLocked ? 'Disabled' : 'Active',
                  ),
                ),
              ],
              actionsBuilder: (context, user) => SizedBox(
                width: _localUserActionsColumnWidth,
                child: _LocalUserRowActions(
                  user: user,
                  onEditDetails: _showEditUserDialog,
                  onResetPassword: _showResetPasswordDialog,
                  onSessions: _showSessionsDialog,
                  onToggleAccount: (targetUser) async {
                    final confirmed = await showAppConfirmationDialog(
                      context: context,
                      title: 'Confirmation Required',
                      message: targetUser.isLocked
                          ? 'Enabling this account will allow the user to log in and perform permitted actions.'
                          : 'Disabling this account will prevent the user from logging in and performing any actions.',
                      confirmLabel: 'Continue',
                      icon: targetUser.isLocked
                          ? Icons.person_outline_outlined
                          : Icons.person_off_outlined,
                    );

                    if (confirmed != true) {
                      return;
                    }

                    if (targetUser.isLocked) {
                      await handleEnableUserAccount(targetUser.id);
                    } else {
                      await handleDisableUserAccount(targetUser.id);
                    }
                  },
                  onDelete: (targetUser) async {
                    final confirmed = await showAppConfirmationDialog(
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

                    await handleDeleteUser(targetUser.id);
                  },
                ),
              ),
              actionsWidth: _localUserActionsColumnWidth,
              rowKey: (user) => user.id,
              isLoading: state.isLoadingUsers,
              hasActiveFilter: state.searchTerm.trim().isNotEmpty,
              emptyState: AdminEmptyStateData(
                title: 'No local users yet.',
                message:
                    'Create a local user to grant access to operators who authenticate directly with this console.',
                primaryAction: FilledButton.icon(
                  onPressed: _showRegisterDialog,
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('New User'),
                ),
                secondaryAction: TextButton.icon(
                  onPressed: controller.loadUsers,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ),
              filteredEmptyState: const AdminEmptyStateData(
                title: 'No matching users.',
                message: 'Clear the search or adjust filters.',
              ),
              minWidth: _tableMinWidth,
              footer: AdminGridFooter(
                state: AdminPaginationState(
                  visibleCount: state.users.length,
                  totalCount: state.total,
                  page: state.page,
                  pages: state.pages,
                  pageSize: state.pageSize,
                  pageSizes: const <int>[15, 25, 50],
                  onPageSizeChanged: (value) async {
                    controller.setRowsPerPage(value);
                    await controller.loadUsers();
                  },
                  onFirstPage: state.page <= 1
                      ? null
                      : () async {
                          controller.setPage(1);
                          await controller.loadUsers();
                        },
                  onPreviousPage: state.page <= 1
                      ? null
                      : () async {
                          controller.setPage(state.page - 1);
                          await controller.loadUsers();
                        },
                  onNextPage: state.page >= state.pages
                      ? null
                      : () async {
                          controller.setPage(state.page + 1);
                          await controller.loadUsers();
                        },
                  onLastPage: state.page >= state.pages
                      ? null
                      : () async {
                          controller.setPage(state.pages);
                          await controller.loadUsers();
                        },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _formatLocalUserDate(DateTime value) {
  return '${value.toUtc()}'.split('.').first;
}

class _LocalUserRowActions extends StatelessWidget {
  const _LocalUserRowActions({
    required this.user,
    required this.onEditDetails,
    required this.onResetPassword,
    required this.onSessions,
    required this.onToggleAccount,
    required this.onDelete,
  });

  final UserEntity user;
  final ValueChanged<UserEntity> onEditDetails;
  final ValueChanged<UserEntity> onResetPassword;
  final ValueChanged<UserEntity> onSessions;
  final ValueChanged<UserEntity> onToggleAccount;
  final ValueChanged<UserEntity> onDelete;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FittedBox(
        alignment: Alignment.centerRight,
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'Edit Details',
              onPressed: () => onEditDetails(user),
            ),
            AdminIconButton(
              icon: Icons.password_outlined,
              tooltip: 'Reset Password',
              onPressed: () => onResetPassword(user),
            ),
            AdminIconButton(
              icon: Icons.history_toggle_off_outlined,
              tooltip: 'Sessions',
              onPressed: () => onSessions(user),
            ),
            AdminIconButton(
              icon: user.isLocked
                  ? Icons.person_outline_outlined
                  : Icons.person_off_outlined,
              tooltip: user.isLocked ? 'Enable Account' : 'Disable Account',
              destructive: !user.isLocked,
              onPressed: () => onToggleAccount(user),
            ),
            AdminIconButton(
              icon: Icons.delete_outline,
              tooltip: 'Delete User',
              destructive: true,
              onPressed: () => onDelete(user),
            ),
          ],
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
      width: _userSessionsDialogMaxWidth,
      child: AppFormPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                decoration: appFormInputDecoration(
                  labelText: 'First Name',
                  helpText: acpFieldHelpText(
                    key: 'FirstName',
                    label: 'First Name',
                  ),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameController,
                decoration: appFormInputDecoration(
                  labelText: 'Last Name',
                  helpText: acpFieldHelpText(
                    key: 'LastName',
                    label: 'Last Name',
                  ),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _userNameController,
                decoration: appFormInputDecoration(
                  labelText: 'Username',
                  helpText: acpFieldHelpText(
                    key: 'Username',
                    label: 'Username',
                  ),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: appFormInputDecoration(
                  labelText: 'Email',
                  helpText: acpFieldHelpText(key: 'Email', label: 'Email'),
                ),
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
                decoration: appFormInputDecoration(
                  labelText: 'Password',
                  helpText: acpFieldHelpText(
                    key: 'Password',
                    label: 'Password',
                  ),
                ),
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
                decoration: appFormInputDecoration(
                  labelText: 'First name',
                  helpText: acpFieldHelpText(
                    key: 'FirstName',
                    label: 'First Name',
                  ),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameController,
                decoration: appFormInputDecoration(
                  labelText: 'Last name',
                  helpText: acpFieldHelpText(
                    key: 'LastName',
                    label: 'Last Name',
                  ),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: appFormInputDecoration(
                  labelText: 'Email',
                  helpText: acpFieldHelpText(key: 'Email', label: 'Email'),
                ),
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
                decoration: appFormInputDecoration(
                  labelText: 'New password',
                  helpText: acpFieldHelpText(
                    key: 'NewPassword',
                    label: 'New Password',
                  ),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: appFormInputDecoration(
                  labelText: 'Confirm new password',
                  helpText: acpFieldHelpText(
                    key: 'ConfirmNewPassword',
                    label: 'Confirm New Password',
                  ),
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
