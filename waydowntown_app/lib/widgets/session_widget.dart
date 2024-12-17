import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/services/user_service.dart';
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
  String? _name;
  bool? _isAdmin;
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
        final attributes = response.data['data']['attributes'];
        setState(() {
          _email = attributes['email'];
          _name = attributes['name'];
          _isAdmin = attributes['admin'] ?? false;
          _isLoading = false;
        });
        await UserService.setUserData(
            response.data['data']['id'], _email!, _isAdmin!,
            name: _name);
        return;
      }

      final email = await UserService.getUserEmail();
      final name = await UserService.getUserName();
      final isAdmin = await UserService.getUserIsAdmin();

      setState(() {
        _email = email;
        _name = name;
        _isAdmin = isAdmin;
        _isLoading = false;
      });
    } catch (error) {
      talker.error('Error checking session: $error');
      setState(() {
        _email = null;
        _isAdmin = null;
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
    await UserService.clearUserData();
    setState(() {
      _email = null;
      _isAdmin = null;
      _isLoading = false;
    });

    await _checkSession();
  }

  Future<void> _updateName(String newName) async {
    try {
      final userId = await UserService.getUserId();
      final response = await widget.dio.post(
        '${widget.apiBaseUrl}/fixme/me',
        data: {
          'data': {
            'type': 'users',
            'id': userId,
            'attributes': {'name': newName}
          }
        },
        options: Options(headers: {
          'Accept': 'application/vnd.api+json',
          'Content-Type': 'application/vnd.api+json',
        }),
      );

      if (response.statusCode == 200) {
        final attributes = response.data['data']['attributes'];
        setState(() {
          _name = attributes['name'];
        });
        await UserService.setUserName(_name!);
      }
    } catch (error) {
      talker.error('Error updating name: $error');
      rethrow;
    }
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

  void _openNameEditDialog() {
    final controller = TextEditingController(text: _name);
    String? errorText;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Name'),
              content: TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Name',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (controller.text.isEmpty) {
                      setState(() {
                        errorText = "Name can't be blank";
                      });
                      return;
                    }
                    try {
                      await _updateName(controller.text);
                      Navigator.of(context).pop();
                    } catch (e) {
                      setState(() {
                        errorText = 'Failed to update name';
                      });
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
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
      return Material(
        type: MaterialType.transparency,
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _openNameEditDialog,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_name ?? _email!,
                          style: const TextStyle(color: Colors.white)),
                      const Icon(Icons.edit, color: Colors.white, size: 16),
                    ],
                  ),
                ),
                Text(_email!,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
            if (_isAdmin == true)
              const Icon(Icons.admin_panel_settings, color: Colors.white),
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
        ),
      );
    }

    return ElevatedButton(
      onPressed: _openAuthForm,
      child: const Text('Log in'),
    );
  }
}
