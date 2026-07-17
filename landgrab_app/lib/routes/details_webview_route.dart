import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/routes/login_route.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Hosts the registrations site's `/details` page inside an in-app
/// WebView. The site handles all the field-management (email, team
/// name, accessibility notes, etc.), so we don't duplicate that form
/// in Dart. Auth is handed off via a short-lived signed URL minted by
/// `LandgrabApi.mintDetailsExchangeUrl`.
class DetailsWebViewRoute extends StatefulWidget {
  final LandgrabApi api;
  const DetailsWebViewRoute({super.key, required this.api});

  @override
  State<DetailsWebViewRoute> createState() => _DetailsWebViewRouteState();
}

class _DetailsWebViewRouteState extends State<DetailsWebViewRoute> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;
  // Fires once when we intercept the post-deletion redirect, so the
  // logout/navigate teardown can't run twice.
  bool _handledDeletion = false;

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
          onNavigationRequest: _onNavigationRequest,
          onWebResourceError: (err) {
            // Ignore subresource errors (favicons, ads, tracking) —
            // only surface main-frame failures.
            if (err.isForMainFrame ?? true) {
              setState(() => _error = err.description);
            }
          },
        ),
      )
      // The /details page raises JavaScript dialogs — notably the
      // `window.confirm("…delete your account…")` behind the
      // "Delete your account" link (a Phoenix `data-confirm`). WebViews
      // show nothing for confirm/alert unless we handle them, and an
      // unhandled confirm resolves to `false`, so the delete silently
      // did nothing. Bridge them to native dialogs.
      ..setOnJavaScriptConfirmDialog((request) => _showConfirm(request.message))
      ..setOnJavaScriptAlertDialog((request) => _showAlert(request.message));
    // A transparent background is a load-time nicety, but on macOS
    // `setBackgroundColor` is unimplemented — the WKWebView backend
    // throws "opaque is not implemented on macOS" — so only set it
    // where it's supported.
    if (!Platform.isMacOS) {
      _controller.setBackgroundColor(Colors.transparent);
    }
    _load();
  }

  /// The details form always redirects back to `/details`; only account
  /// deletion leaves for the site root (Pow's `after_user_deleted_path`
  /// is "/"). So a navigation to the root means the account is gone —
  /// tear down the app session and return to login rather than loading
  /// the public landing page inside the WebView.
  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final path = Uri.parse(request.url).path;
    if ((path.isEmpty || path == '/') && !_handledDeletion) {
      _handledDeletion = true;
      _onAccountDeleted();
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _onAccountDeleted() async {
    // Clears local tokens; the DELETE /powapi/session it also attempts
    // just 401s (account already gone) and is swallowed.
    await widget.api.logout();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(DetailsStrings.accountDeleted)),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginRoute(api: widget.api)),
      (route) => false,
    );
  }

  Future<bool> _showConfirm(String message) async {
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(DetailsStrings.dialogCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(DetailsStrings.dialogOk),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _showAlert(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(DetailsStrings.dialogOk),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = await widget.api.mintDetailsExchangeUrl();
      await _controller.loadRequest(Uri.parse(url));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = DetailsStrings.couldNotOpen(e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(DetailsStrings.appBarTitle),
        actions: [
          IconButton(
            tooltip: DetailsStrings.reloadTooltip,
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_error == null) WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
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
                      label: const Text(DetailsStrings.tryAgain),
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
