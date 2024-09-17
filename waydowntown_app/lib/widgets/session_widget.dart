import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waydowntown/tools/auth_webview.dart';

class SessionWidget extends StatefulWidget {
  final Dio dio;
  final String apiBaseUrl;

  const SessionWidget({Key? key, required this.dio, required this.apiBaseUrl})
      : super(key: key);

  @override
  _SessionWidgetState createState() => _SessionWidgetState();
}

class _SessionWidgetState extends State<SessionWidget> {
  String? _email;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final cookieString = prefs.getString('auth_cookie');

    if (cookieString != null) {
      try {
        final response = await widget.dio.get(
          '/fixme/session',
          options: Options(headers: {'Cookie': cookieString}),
        );

        if (response.statusCode == 200) {
          setState(() {
            _email = response.data['data']['attributes']['email'];
            _isLoading = false;
          });
          return;
        }
      } catch (error) {
        print('Error checking session: $error');
      }
    }

    setState(() {
      _email = null;
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_cookie');
    _checkSession();
  }

  void _openAuthWebView() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AuthWebView(
          apiBaseUrl: widget.apiBaseUrl,
          dio: widget.dio,
        ),
      ),
    );
    _checkSession();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }

    if (_email != null) {
      return Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8, // Add some space between the email and the logout button
        children: [
          Text('$_email', style: const TextStyle(color: Colors.white)),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Log out',
          ),
        ],
      );
    }

    return ElevatedButton(
      onPressed: _openAuthWebView,
      child: const Text('Log in'),
    );
  }
}
