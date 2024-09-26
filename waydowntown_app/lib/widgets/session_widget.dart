import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waydowntown/tools/auth_form.dart';

class SessionWidget extends StatefulWidget {
  final Dio dio;
  final String apiBaseUrl;

  const SessionWidget({super.key, required this.dio, required this.apiBaseUrl});

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
    final otherDio = Dio();

    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('access_token');

    if (authToken != null) {
      try {
        final response = await otherDio.get(
          '${widget.apiBaseUrl}/fixme/session',
          options: Options(headers: {
            'Authorization': authToken,
          }),
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
    await prefs.remove('access_token');
    _checkSession();
  }

  void _openAuthForm() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Log in'),
          content: AuthFormWidget(
            dio: widget.dio,
            apiBaseUrl: widget.apiBaseUrl,
            onAuthSuccess: () {
              Navigator.of(context).pop();
              _checkSession();
            },
          ),
        );
      },
    );
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
      onPressed: _openAuthForm,
      child: const Text('Log in'),
    );
  }
}
