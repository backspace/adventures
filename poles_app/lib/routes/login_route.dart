import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/flavors.dart';
import 'package:poles/routes/home_route.dart';
import 'package:poles/routes/settings_route.dart';
import 'package:poles/services/env_service.dart';

class LoginRoute extends StatefulWidget {
  final PolesApi api;
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

    final ok = await widget.api.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (ok) {
      TextInput.finishAutofillContext();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeRoute(api: widget.api)),
      );
    } else {
      setState(() {
        _busy = false;
        _error = 'Invalid email or password';
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
      appBar: AppBar(
        title: const Text('Sign in'),
        actions: [
          if (F.allowsEnvSwitch)
            IconButton(
              tooltip: 'Switch environment',
              icon: const Icon(Icons.dns_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsRoute()),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EnvBanner(
              flavorTitle: F.title,
              apiRoot: apiRoot,
              showSwitcher: F.allowsEnvSwitch,
            ),
            const SizedBox(height: 24),
            AutofillGroup(
              child: Column(
                children: [
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email, AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(labelText: 'Password'),
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
                  : const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnvBanner extends StatelessWidget {
  final String flavorTitle;
  final String apiRoot;
  final bool showSwitcher;

  const _EnvBanner({
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
                  Text(flavorTitle,
                      style: theme.textTheme.titleMedium),
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
                  MaterialPageRoute(builder: (_) => const SettingsRoute()),
                ),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Switch'),
              ),
          ],
        ),
      ),
    );
  }
}
