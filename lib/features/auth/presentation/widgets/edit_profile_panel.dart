import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/application/dto/update_own_profile_input.dart';
import 'package:mugen_ui/features/auth/domain/entities/own_profile_entity.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

class EditProfilePanel extends ConsumerStatefulWidget {
  const EditProfilePanel({super.key}); // coverage:ignore-line

  @override
  ConsumerState<EditProfilePanel> createState() => _EditProfilePanelState();
}

class _EditProfilePanelState extends ConsumerState<EditProfilePanel> {
  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  OwnProfileEntity? _profile;
  String? _profileLoadError;
  bool _loadingProfile = true;
  bool _savingProfile = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadProfile);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _profileLoadError = null;
    });

    final result = await ref
        .read(authApplicationServiceProvider)
        .fetchOwnProfile();
    if (!mounted) {
      return;
    }

    if (result.isFailure) {
      setState(() {
        _loadingProfile = false;
        _profile = null;
        _profileLoadError =
            result.failure?.message ?? 'Could not load profile.';
      });
      return;
    }

    final profile = result.data!;
    setState(() {
      _loadingProfile = false;
      _profile = profile;
      _profileLoadError = null;
      _firstNameController.text = profile.firstName;
      _lastNameController.text = profile.lastName;
    });
  }

  Future<void> _saveProfile() async {
    final isValid = _profileFormKey.currentState?.validate() ?? false;
    if (!isValid || _profile == null) {
      return;
    }

    setState(() {
      _savingProfile = true;
    });

    final result = await ref
        .read(authApplicationServiceProvider)
        .updateOwnProfile(
          UpdateOwnProfileInput(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            personRowVersion: _profile!.personRowVersion,
          ),
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _savingProfile = false;
    });

    final snackBar = ref.read(snackBarDispatcherProvider);
    final navigator = ref.read(appNavigatorProvider);
    if (result.isFailure) {
      snackBar.show(
        navigator,
        result.failure?.message ?? 'Profile update failed. Please try again.',
      );
      return;
    }

    snackBar.show(navigator, 'Profile updated successfully.');
    await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppFormPanel(
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppUiPalette.surfaceStrong,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 18,
                    color: AppUiPalette.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Profile',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Update your first and last name.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppUiPalette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildProfileContent(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(ThemeData theme) {
    if (_loadingProfile) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_profileLoadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _profileLoadError!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppUiPalette.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _loadProfile, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _savingProfile
                  ? null
                  : () => Navigator.of(context).maybePop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _savingProfile ? null : _saveProfile,
              child: _savingProfile
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Profile'),
            ),
          ],
        ),
      ],
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Field cannot be empty.';
    }

    return null;
  }
}
