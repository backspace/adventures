import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/flavors.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/routes/credits_route.dart';
import 'package:landgrab/widgets/password_field.dart';
import 'package:landgrab/routes/forgot_password_route.dart';
import 'package:landgrab/routes/home_route.dart';
import 'package:landgrab/routes/register_route.dart';
import 'package:landgrab/routes/settings_route.dart';
import 'package:landgrab/services/env_service.dart';
import 'package:landgrab/services/env_switch_service.dart';
import 'package:landgrab/widgets/landgrab_app_bar.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginRoute extends StatefulWidget {
  final LandgrabApi api;
  const LoginRoute({super.key, required this.api});

  @override
  State<LoginRoute> createState() => _LoginRouteState();
}

class _LoginRouteState extends State<LoginRoute> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final outcome = await widget.api.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (outcome == LoginOutcome.success) {
      TextInput.finishAutofillContext();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeRoute(api: widget.api)),
      );
    } else {
      setState(() {
        _busy = false;
        _error = switch (outcome) {
          LoginOutcome.invalidCredentials => LoginStrings.invalidCredentials,
          LoginOutcome.unreachable => LoginStrings.serverUnreachable,
          _ => LoginStrings.loginFailed,
        };
      });
    }
  }

  Future<void> _signInWithGoogle() => _signInWithProvider('google', 'Google');

  Future<void> _signInWithApple() async {
    // iOS gets the native "Sign in with Apple" sheet via the platform
    // SDK; Android has no native flow so we fall back to the standard
    // OAuth web flow (safari/custom-tabs → mobile_bounce → app).
    if (Platform.isIOS || Platform.isMacOS) {
      await _signInWithAppleNative();
    } else {
      await _signInWithProvider('apple', 'Apple');
    }
  }

  Future<void> _signInWithAppleNative() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final token = credential.identityToken;
      if (token == null) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = LoginStrings.appleNoIdentityToken;
        });
        return;
      }
      await _submitAppleToken(
        token,
        email: credential.email,
        givenName: credential.givenName,
        familyName: credential.familyName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      // Includes the user tapping "Cancel" on the sheet — treat as a
      // quiet dismissal rather than an error message.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.code == AuthorizationErrorCode.canceled
            ? null
            : LoginStrings.appleSignInFailedWith(e.message);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = LoginStrings.appleSignInFailedWith(e.toString());
      });
    }
  }

  /// Submit an Apple identity token to the server. If Apple withheld the email
  /// for a new user, prompt for one and resubmit the SAME token (valid for a
  /// few minutes, reusable). [_busy] stays true across the prompt so the
  /// buttons remain disabled; only terminal states clear it.
  Future<void> _submitAppleToken(
    String token, {
    String? email,
    String? givenName,
    String? familyName,
  }) async {
    final result = await widget.api.loginWithAppleNative(
      identityToken: token,
      email: email,
      givenName: givenName,
      familyName: familyName,
    );
    if (!mounted) return;
    switch (result.status) {
      case AppleNativeStatus.success:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeRoute(api: widget.api)),
        );
      case AppleNativeStatus.emailRequired:
        final entered = await _promptForAppleEmail();
        if (!mounted) return;
        if (entered == null) {
          // Cancelled the email prompt — abandon quietly, no error.
          setState(() {
            _busy = false;
            _error = null;
          });
          return;
        }
        await _submitAppleToken(
          token,
          email: entered,
          givenName: givenName,
          familyName: familyName,
        );
      case AppleNativeStatus.failed:
        setState(() {
          _busy = false;
          _error = result.detail == null
              ? LoginStrings.appleSignInFailed
              : LoginStrings.appleSignInFailedWith(result.detail!);
        });
    }
  }

  /// Ask for an email when Apple didn't provide one. Returns the trimmed
  /// address, or null if cancelled. Requires an "@" before enabling submit —
  /// the server's email format check would otherwise reject it.
  Future<String?> _promptForAppleEmail() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final value = controller.text.trim();
            final valid = value.contains('@') && !value.startsWith('@');
            return AlertDialog(
              title: const Text(LoginStrings.appleEmailTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(LoginStrings.appleEmailBody),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: LoginStrings.emailLabel,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                    onSubmitted: (_) {
                      if (valid) Navigator.of(dialogContext).pop(value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(LoginStrings.appleEmailCancel),
                ),
                FilledButton(
                  onPressed:
                      valid ? () => Navigator.of(dialogContext).pop(value) : null,
                  child: const Text(LoginStrings.appleEmailContinue),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _signInWithProvider(String provider, String label) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.api.loginWithOAuth(provider);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeRoute(api: widget.api)),
      );
    } else {
      setState(() {
        _busy = false;
        _error = LoginStrings.oauthCancelled(label);
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apiRoot = EnvService.instance.currentApiRoot.value ?? '';

    return Scaffold(
      appBar: LandgrabAppBar(
        title: LoginStrings.appBarTitle,
        actions: [
          IconButton(
            tooltip: GameplayStrings.credits,
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreditsRoute()),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: EnvSwitchService.visible,
            builder: (context, envVisible, _) => envVisible
                ? IconButton(
                    tooltip: LoginStrings.switchEnvironmentTooltip,
                    icon: const Icon(Icons.dns_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SettingsRoute(api: widget.api)),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: EnvSwitchService.visible,
              builder: (context, envVisible, _) => envVisible
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: _EnvBanner(
                        api: widget.api,
                        flavorTitle: F.title,
                        apiRoot: apiRoot,
                        showSwitcher: true,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            AutofillGroup(
              child: Column(
                children: [
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [
                      AutofillHints.email,
                      AutofillHints.username
                    ],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: LoginStrings.emailLabel),
                  ),
                  const SizedBox(height: 12),
                  PasswordField(
                    controller: _passwordController,
                    labelText: LoginStrings.passwordLabel,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(LoginStrings.signInButton),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ForgotPasswordRoute(api: widget.api),
                          ),
                        ),
                child: const Text(LoginStrings.forgotPassword),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: const [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(LoginStrings.orDivider),
              ),
              Expanded(child: Divider()),
            ]),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _busy ? null : _signInWithGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 28),
              label: const Text(LoginStrings.signInWithGoogle),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _signInWithApple,
              icon: const Icon(Icons.apple, size: 22),
              label: const Text(LoginStrings.signInWithApple),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(LoginStrings.noAccountPrompt),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RegisterRoute(api: widget.api),
                            ),
                          ),
                  child: const Text(LoginStrings.createAccountLink),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EnvBanner extends StatelessWidget {
  final LandgrabApi api;
  final String flavorTitle;
  final String apiRoot;
  final bool showSwitcher;

  const _EnvBanner({
    required this.api,
    required this.flavorTitle,
    required this.apiRoot,
    required this.showSwitcher,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(flavorTitle, style: theme.textTheme.titleMedium),
                  Text(
                    apiRoot,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (showSwitcher)
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SettingsRoute(api: api)),
                ),
                icon: const Icon(Icons.dns_outlined),
                label: const Text(LoginStrings.switchButton),
              ),
          ],
        ),
      ),
    );
  }
}
