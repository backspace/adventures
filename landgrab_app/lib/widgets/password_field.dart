import 'package:flutter/material.dart';

/// A password text field with a show/hide ("eye") toggle. Owns the
/// obscure-text state internally, so callers just supply the controller,
/// label, and the usual autofill/submit wiring.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final List<String>? autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const PasswordField({
    super.key,
    required this.controller,
    required this.labelText,
    this.autofillHints,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscured,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.labelText,
        suffixIcon: IconButton(
          // Open eye while hidden (tap to reveal); crossed-out eye while
          // shown (tap to hide) — the standard toggle affordance.
          icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
          tooltip: _obscured ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}
