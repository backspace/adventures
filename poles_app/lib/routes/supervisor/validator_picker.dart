import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/validation.dart';

/// Modal sheet showing the list of users with the validator role.
/// Returns the selected validator, or null if cancelled.
Future<ValidatorUser?> pickValidator(
  BuildContext context, {
  required PolesApi api,
  String? excludeUserId,
}) {
  return showModalBottomSheet<ValidatorUser>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _ValidatorPicker(api: api, excludeUserId: excludeUserId),
  );
}

class _ValidatorPicker extends StatefulWidget {
  final PolesApi api;
  final String? excludeUserId;

  const _ValidatorPicker({required this.api, this.excludeUserId});

  @override
  State<_ValidatorPicker> createState() => _ValidatorPickerState();
}

class _ValidatorPickerState extends State<_ValidatorPicker> {
  List<ValidatorUser>? _list;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.api.listValidators(excludeUserId: widget.excludeUserId);
      if (!mounted) return;
      setState(() => _list = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Assign to validator',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const Divider(height: 1),
            Flexible(
              child: _error != null
                  ? Center(child: Text('Could not load validators: $_error'))
                  : _list == null
                      ? const Center(child: CircularProgressIndicator())
                      : _list!.isEmpty
                          ? const Center(child: Text('No eligible validators.'))
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _list!.length,
                              itemBuilder: (_, i) {
                                final v = _list![i];
                                return ListTile(
                                  title: Text(v.name ?? v.email),
                                  subtitle: v.name == null ? null : Text(v.email),
                                  onTap: () => Navigator.of(context).pop(v),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
