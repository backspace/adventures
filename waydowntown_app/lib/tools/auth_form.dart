import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'
    as secure_storage;

class AuthFormWidget extends StatefulWidget {
  final Dio dio;
  final String apiBaseUrl;
  final Function onAuthSuccess;

  const AuthFormWidget({
    super.key,
    required this.dio,
    required this.apiBaseUrl,
    required this.onAuthSuccess,
  });

  @override
  _AuthFormWidgetState createState() => _AuthFormWidgetState();
}

class _AuthFormWidgetState extends State<AuthFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  bool _isLoading = false;

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final response = await widget.dio.post(
          '${widget.apiBaseUrl}/powapi/session',
          options: Options(headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          }),
          data: {
            'user': {
              'email': _emailController.text,
              'password': _passwordController.text,
            },
          },
        );

        if (response.statusCode == 200) {
          final accessToken = response.data['data']['access_token'];
          final renewalToken = response.data['data']['renewal_token'];

          const secureStorage = secure_storage.FlutterSecureStorage();
          await secureStorage.write(key: 'access_token', value: accessToken);
          await secureStorage.write(key: 'renewal_token', value: renewalToken);

          widget.onAuthSuccess();
        } else {
          // Handle error (e.g., show error message)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication failed')),
          );
        }
      } catch (error) {
        print('Error during authentication: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: TextFieldTapRegion(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) {
                FocusScope.of(context).requestFocus(_passwordFocusNode);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submitForm(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Log in'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }
}
