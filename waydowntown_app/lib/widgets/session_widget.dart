import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'
    as secure_storage;
import 'package:waydowntown/app.dart';
import 'package:waydowntown/tools/auth_form.dart';
import 'package:waydowntown/tools/my_specifications_table.dart';

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
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _getSession();
      if (response.statusCode == 200) {
        setState(() {
          _email = response.data['data']['attributes']['email'];
          _isLoading = false;
        });
        return;
      }
    } catch (error) {
      talker.error('Error checking session: $error');

      setState(() {
        _email = null;
        _isLoading = false;
      });
    }
  }

  Future<Response> _getSession() {
    return widget.dio.get(
      '${widget.apiBaseUrl}/fixme/session',
      options: Options(headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      }),
    );
  }

  Future<void> _logout() async {
    const secureStorage = secure_storage.FlutterSecureStorage();
    await secureStorage.delete(key: 'access_token');
    await secureStorage.delete(key: 'renewal_token');

    setState(() {
      _email = null;
      _isLoading = false;
    });

    await _checkSession();
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
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MySpecificationsTable(dio: widget.dio),
              ),
            ),
            child: const Text('My specifications'),
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
