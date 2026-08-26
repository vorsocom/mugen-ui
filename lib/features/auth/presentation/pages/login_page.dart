import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/portal/presentation/widgets/portal_page_shell.dart';
import 'package:mugen_ui/features/tenant_invite/presentation/providers/pending_invite_providers.dart';
import 'package:mugen_ui/shared/presentation/portal/portal_definition.dart';
import 'package:mugen_ui/shared/presentation/portal/portal_theme_tokens.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final didLogin = await ref
        .read(authControllerProvider.notifier)
        .login(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
    if (!didLogin || !mounted) {
      return;
    }

    final pendingInvite = ref
        .read(pendingInviteControllerProvider.notifier)
        .consume();
    final destination = pendingInvite == null
        ? AppRoutePaths.app
        : AppRoutePaths.buildInviteRoute(
            tenantId: pendingInvite.tenantId,
            invitationId: pendingInvite.invitationId,
            token: pendingInvite.token,
          );
    await ref.read(appNavigatorProvider).navigateTo(destination);
  }

  @override
  Widget build(BuildContext context) {
    final definition = ref.watch(portalDefinitionProvider);
    final authState = ref.watch(authControllerProvider);

    return PopScope(
      canPop: false,
      child: PortalPageShell(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < PortalLayoutTokens.loginStackBreakpoint;
            final stage = Container(
              key: const Key('portal-login-stage'),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  PortalLayoutTokens.loginStageRadius,
                ),
                border: Border.all(color: definition.theme.line),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: definition.theme.shadow,
                    blurRadius: 40,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LoginStory(definition: definition, compact: true),
                        _LoginPanel(
                          definition: definition,
                          authState: authState,
                          formKey: _formKey,
                          usernameController: _usernameController,
                          passwordController: _passwordController,
                          obscurePassword: _obscurePassword,
                          onTogglePassword: () => setState(() {
                            _obscurePassword = !_obscurePassword;
                          }),
                          onSubmit: _handleSubmit,
                        ),
                      ],
                    )
                  : IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _LoginStory(definition: definition)),
                          Expanded(
                            child: _LoginPanel(
                              definition: definition,
                              authState: authState,
                              formKey: _formKey,
                              usernameController: _usernameController,
                              passwordController: _passwordController,
                              obscurePassword: _obscurePassword,
                              onTogglePassword: () => setState(() {
                                _obscurePassword = !_obscurePassword;
                              }),
                              onSubmit: _handleSubmit,
                            ),
                          ),
                        ],
                      ),
                    ),
            );

            return Padding(
              padding: EdgeInsets.only(
                top: stacked ? 34 : 58,
                bottom: stacked ? 34 : 48,
              ),
              child: stacked
                  ? stage
                  : ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 640),
                      child: stage,
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _LoginStory extends StatelessWidget {
  const _LoginStory({required this.definition, this.compact = false});

  final PortalDefinition definition;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = definition.login;
    final theme = definition.theme;

    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: theme.graphite)),
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Opacity(
                opacity: 0.08,
                child: Image.asset(
                  definition.technicalPatternAssetPath,
                  repeat: ImageRepeat.repeat,
                  fit: BoxFit.none,
                  color: theme.onGraphite,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: compact
              ? const EdgeInsets.fromLTRB(28, 34, 28, 38)
              : const EdgeInsets.fromLTRB(46, 66, 46, 58),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionKicker(
                text: content.storyKicker,
                color: theme.onGraphiteMuted,
              ),
              const SizedBox(height: 22),
              Semantics(
                header: true,
                child: Text(
                  content.storyTitle.toUpperCase(),
                  key: const Key('portal-login-story-title'),
                  style: TextStyle(
                    color: theme.onGraphite,
                    fontFamily: theme.displayFontFamily,
                    fontSize: compact ? 40 : 50,
                    fontWeight: FontWeight.w400,
                    height: 1.03,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                content.storyDescription,
                style: TextStyle(
                  color: theme.onGraphiteMuted,
                  fontFamily: theme.bodyFontFamily,
                  fontSize: 14,
                  height: 1.65,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 38),
                ...content.accessPoints.indexed.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            (entry.$1 + 1).toString().padLeft(2, '0'),
                            style: TextStyle(
                              color: theme.indigo,
                              fontFamily: 'monospace',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              height: 1.65,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.$2,
                            style: TextStyle(
                              color: theme.onGraphiteMuted,
                              fontFamily: theme.bodyFontFamily,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.definition,
    required this.authState,
    required this.formKey,
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final PortalDefinition definition;
  final AuthControllerState authState;
  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final content = definition.login;
    final theme = definition.theme;
    final bodyStyle = TextStyle(
      color: theme.ink,
      fontFamily: theme.bodyFontFamily,
    );

    return ColoredBox(
      color: theme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(38, 34, 38, 42),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: PortalBackLink(),
              ),
              const SizedBox(height: 24),
              _SectionKicker(
                text: content.accountKicker,
                color: theme.indigoDark,
              ),
              const SizedBox(height: 15),
              Semantics(
                header: true,
                child: Text(
                  content.title.toUpperCase(),
                  key: const Key('portal-login-title'),
                  style: TextStyle(
                    color: theme.titleInk,
                    fontFamily: theme.displayFontFamily,
                    fontSize: 45,
                    fontWeight: FontWeight.w400,
                    height: 1,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                content.description,
                style: bodyStyle.copyWith(
                  color: theme.muted,
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 30),
              _PortalFormLabel(
                label: 'Username',
                helpText:
                    'Enter the username for the local account you want to sign in with.',
                theme: theme,
              ),
              const SizedBox(height: 7),
              TextFormField(
                key: const Key('login-username-field'),
                controller: usernameController,
                enabled: !authState.isLoading,
                autofocus: true,
                autofillHints: const <String>[AutofillHints.username],
                textInputAction: TextInputAction.next,
                style: bodyStyle.copyWith(fontSize: 14),
                decoration: _portalInputDecoration(
                  theme: theme,
                  hintText: 'Enter your username',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Field cannot be empty.'
                    : null,
              ),
              const SizedBox(height: 18),
              _PortalFormLabel(
                label: 'Password',
                helpText:
                    'Enter the password used to authenticate this sign-in attempt.',
                theme: theme,
              ),
              const SizedBox(height: 7),
              TextFormField(
                key: const Key('login-password-field'),
                controller: passwordController,
                enabled: !authState.isLoading,
                obscureText: obscurePassword,
                autofillHints: const <String>[AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => onSubmit(),
                style: bodyStyle.copyWith(fontSize: 14),
                decoration: _portalInputDecoration(
                  theme: theme,
                  hintText: 'Enter your password',
                  suffixIcon: IconButton(
                    key: const Key('login-password-visibility'),
                    tooltip: obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: authState.isLoading ? null : onTogglePassword,
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Field cannot be empty.'
                    : null,
              ),
              const SizedBox(height: 22),
              if (authState.errorMessage != null) ...[
                AppErrorAlert(message: authState.errorMessage!),
                const SizedBox(height: 16),
              ],
              FilledButton(
                key: const Key('login-submit-button'),
                onPressed: authState.isLoading ? null : () => onSubmit(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: theme.indigo,
                  disabledBackgroundColor: theme.indigo.withValues(alpha: 0.45),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: bodyStyle.copyWith(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: authState.isLoading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Sign in'),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, color: theme.muted, size: 14),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      content.status,
                      key: const Key('portal-login-security-status'),
                      textAlign: TextAlign.center,
                      style: bodyStyle.copyWith(
                        color: theme.muted,
                        fontSize: 10,
                        letterSpacing: 0.25,
                      ),
                    ),
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

class _SectionKicker extends StatelessWidget {
  const _SectionKicker({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
      ),
    );
  }
}

class _PortalFormLabel extends StatelessWidget {
  const _PortalFormLabel({
    required this.label,
    required this.helpText,
    required this.theme,
  });

  final String label;
  final String helpText;
  final PortalThemeTokens theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.ink,
            fontFamily: theme.bodyFontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 5),
        AppFieldHelpIcon(message: helpText),
      ],
    );
  }
}

InputDecoration _portalInputDecoration({
  required PortalThemeTokens theme,
  required String hintText,
  Widget? suffixIcon,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(PortalLayoutTokens.inputRadius),
    borderSide: BorderSide(color: theme.line),
  );
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(
      color: theme.muted.withValues(alpha: 0.78),
      fontFamily: theme.bodyFontFamily,
      fontSize: 13,
    ),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.72),
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
    suffixIcon: suffixIcon,
    enabledBorder: border,
    disabledBorder: border,
    errorBorder: border.copyWith(
      borderSide: const BorderSide(color: Color(0xFFA64949)),
    ),
    focusedErrorBorder: border.copyWith(
      borderSide: const BorderSide(color: Color(0xFFA64949), width: 1.5),
    ),
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: theme.indigo, width: 1.5),
    ),
  );
}
