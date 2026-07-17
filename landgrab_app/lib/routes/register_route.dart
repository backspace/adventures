import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/routes/details_webview_route.dart';
import 'package:landgrab/routes/home_route.dart';

/// Email/password sign-up for attendees who show up without having
/// registered ahead of time. On success the account is created and
/// signed in in one step, then we drop the user straight into the
/// `/details` WebView to fill in their profile (team, accessibility,
/// attending, …) — the same form the registrations site uses.
class RegisterRoute extends StatefulWidget {
  final LandgrabApi api;
  const RegisterRoute({super.key, required this.api});

  @override
  State<RegisterRoute> createState() => _RegisterRouteState();
}

class _RegisterRouteState extends State<RegisterRoute> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final outcome = await widget.api.register(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (outcome.status == RegisterStatus.success) {
      TextInput.finishAutofillContext();
      // Clear the auth stack down to Home, then open details on top so
      // finishing (or backing out of) the form lands the user on Home.
      final navigator = Navigator.of(context);
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeRoute(api: widget.api)),
        (route) => false,
      );
      navigator.push(
        MaterialPageRoute(
          builder: (_) => DetailsWebViewRoute(api: widget.api),
        ),
      );
    } else {
      setState(() {
        _busy = false;
        _error = switch (outcome.status) {
          // Prefer the server's specific per-field message when we have
          // one (e.g. "Email has already been taken").
          RegisterStatus.invalid =>
            outcome.message ?? RegisterStrings.failed,
          RegisterStatus.unreachable => RegisterStrings.serverUnreachable,
          _ => RegisterStrings.failed,
        };
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(RegisterStrings.appBarTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(RegisterStrings.intro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            AutofillGroup(
              child: Column(
                children: [
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: RegisterStrings.emailLabel),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                        labelText: RegisterStrings.passwordLabel),
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
                  : const Text(RegisterStrings.createAccountButton),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(RegisterStrings.haveAccountPrompt),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text(RegisterStrings.signInLink),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
