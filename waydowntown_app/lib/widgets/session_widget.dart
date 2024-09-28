import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('access_token');

    if (authToken != null) {
      try {
        final response = await _getSession(authToken);
        if (response.statusCode == 200) {
          setState(() {
            _email = response.data['data']['attributes']['email'];
            _isLoading = false;
          });
          return;
        }
      } catch (error) {
        if (error is DioException && error.response?.statusCode == 401) {
          final renewalToken = prefs.getString('renewal_token');
          if (renewalToken != null) {
            final renewedSession = await _renewSession(renewalToken);
            if (renewedSession) {
              await _checkSession();
              return;
            }
          }
        }
        print('Error checking session: $error');
        await _logout();
      }
    }

    setState(() {
      _email = null;
      _isLoading = false;
    });
  }

  Future<Response> _getSession(String authToken) {
    return widget.dio.get(
      '${widget.apiBaseUrl}/fixme/session',
      options: Options(headers: {
        'Authorization': authToken,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      }),
    );
  }

  Future<bool> _renewSession(String renewalToken) async {
    try {
      final response = await widget.dio.post(
        '${widget.apiBaseUrl}/powapi/session/renew',
        options: Options(headers: {
          'Authorization': renewalToken,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        }),
      );

      if (response.statusCode == 200) {
        final accessToken = response.data['data']['access_token'];
        final newRenewalToken = response.data['data']['renewal_token'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken);
        await prefs.setString('renewal_token', newRenewalToken);
        return true;
      }
    } catch (error) {
      print('Error renewing session: $error');
    }
    return false;
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
