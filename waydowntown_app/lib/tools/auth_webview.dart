import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AuthWebView extends StatefulWidget {
  final String apiBaseUrl;
  final Dio dio;

  const AuthWebView({
    super.key,
    required this.apiBaseUrl,
    required this.dio,
  });

  @override
  _AuthWebViewState createState() => _AuthWebViewState();
}

class _AuthWebViewState extends State<AuthWebView> {
  late WebViewController _controller;
  final cookieManager = WebviewCookieManager();
  String? _email;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setUserAgent(
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1')
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (url.endsWith('/details')) {
              _getSession();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('${widget.apiBaseUrl}/session/new'));
  }

  void _getSession() async {
    final cookies = await cookieManager.getCookies(widget.apiBaseUrl);
    final cookieString = cookies.map((c) => '${c.name}=${c.value}').join('; ');

    try {
      final response = await widget.dio.get(
        '/fixme/session',
        options: Options(headers: {'Cookie': cookieString}),
      );

      if (response.statusCode == 200) {
        final email = response.data['data']['attributes']['email'];
        setState(() {
          _email = email;
        });
      }
    } catch (error) {
      print('Error fetching session: $error');
      // Handle error (e.g., show an error message)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Column(
        children: [
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
          if (_email != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Logged in as: $_email'),
            ),
        ],
      ),
    );
  }
}
