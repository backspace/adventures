import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/widgets/landgrab_app_bar.dart';

/// Native "request a password-reset email" form. Collects the user's email
/// and calls [LandgrabApi.requestPasswordReset], which triggers the same
/// PowResetPassword email the web flow sends. The "choose a new password"
/// step happens through the emailed link, which opens in the system
/// browser.
///
/// This used to host the site's `/reset-password/new` page in a WebView, but
/// after the form is submitted Pow redirects to the login page — whose
/// "Sign in with Google" button trips Google's `disallowed_useragent` block
/// inside a WebView. A native form sidesteps the WebView (and that button)
/// entirely.
class ForgotPasswordRoute extends StatefulWidget {
  final LandgrabApi api;
  const ForgotPasswordRoute({super.key, required this.api});

  @override
  State<ForgotPasswordRoute> createState() => _ForgotPasswordRouteState();
}

class _ForgotPasswordRouteState extends State<ForgotPasswordRoute> {
  final _emailController = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = ForgotPasswordStrings.emailRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.api.requestPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _sent = true;
      } else {
        _error = ForgotPasswordStrings.serverUnreachable;
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LandgrabAppBar(title: ForgotPasswordStrings.appBarTitle),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _sent ? _confirmation(context) : _form(context),
      ),
    );
  }

  Widget _form(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(ForgotPasswordStrings.intro),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email, AutofillHints.username],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_busy) _submit();
          },
          decoration: const InputDecoration(
            labelText: ForgotPasswordStrings.emailLabel,
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
              : const Text(ForgotPasswordStrings.submitButton),
        ),
      ],
    );
  }

  Widget _confirmation(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 48),
        const SizedBox(height: 16),
        const Text(
          ForgotPasswordStrings.sent,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(ForgotPasswordStrings.backToSignIn),
        ),
      ],
    );
  }
}
