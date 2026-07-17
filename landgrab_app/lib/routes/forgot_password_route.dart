import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/services/env_service.dart';
import 'package:landgrab/widgets/landgrab_app_bar.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Hosts the registrations site's public `/reset-password/new` page in
/// an in-app WebView. Password reset is a PowResetPassword web flow: the
/// user enters their email here, the server emails a reset link, and
/// that link opens the set-a-new-password page in their browser. The
/// page needs no authentication, so — unlike the details WebView — there
/// is no session hand-off; we just load it against the current API root.
class ForgotPasswordRoute extends StatefulWidget {
  const ForgotPasswordRoute({super.key});

  @override
  State<ForgotPasswordRoute> createState() => _ForgotPasswordRouteState();
}

class _ForgotPasswordRouteState extends State<ForgotPasswordRoute> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (_) {},
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (err) {
            if (err.isForMainFrame ?? true) {
              setState(() => _error = err.description);
            }
          },
        ),
      );
    // setBackgroundColor is unimplemented on macOS (see the note in
    // DetailsWebViewRoute) — only set the transparent load background
    // where it's supported.
    if (!Platform.isMacOS) {
      _controller.setBackgroundColor(Colors.transparent);
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final apiRoot = EnvService.instance.currentApiRoot.value;
    if (apiRoot == null || apiRoot.isEmpty) {
      setState(() {
        _loading = false;
        _error = ForgotPasswordStrings.couldNotOpen('no server configured');
      });
      return;
    }
    try {
      // resolve() against an absolute path yields scheme+host+path
      // regardless of any trailing slash on the configured root.
      final url = Uri.parse(apiRoot).resolve('/reset-password/new');
      await _controller.loadRequest(url);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ForgotPasswordStrings.couldNotOpen(e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LandgrabAppBar(
        title: ForgotPasswordStrings.appBarTitle,
        actions: [
          IconButton(
            tooltip: ForgotPasswordStrings.reloadTooltip,
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_error == null) WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text(ForgotPasswordStrings.tryAgain),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
