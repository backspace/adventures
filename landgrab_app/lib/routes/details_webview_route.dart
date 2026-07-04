import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (_) {},
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (err) {
            // Ignore subresource errors (favicons, ads, tracking) —
            // only surface main-frame failures.
            if (err.isForMainFrame ?? true) {
              setState(() => _error = err.description);
            }
          },
        ),
      );
    _load();
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
        _error = 'Could not open your details page: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        actions: [
          IconButton(
            tooltip: 'Reload',
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
                      label: const Text('Try again'),
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
