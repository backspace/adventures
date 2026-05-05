import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/validation.dart';
import 'package:poles/routes/validator/pole_validation_detail_route.dart';
import 'package:poles/routes/validator/puzzlet_validation_detail_route.dart';
import 'package:poles/widgets/status_badge.dart';

class ValidatorRoute extends StatefulWidget {
  final PolesApi api;
  const ValidatorRoute({super.key, required this.api});

  @override
  State<ValidatorRoute> createState() => _ValidatorRouteState();
}

class _ValidatorRouteState extends State<ValidatorRoute> {
  MyValidations? _validations;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final v = await widget.api.listMyValidations();
      if (!mounted) return;
      setState(() => _validations = v);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load assignments: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My validations'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Poles'),
            Tab(text: 'Puzzlets'),
          ]),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: _error != null
            ? Center(child: Text(_error!))
            : _validations == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(children: [
                    _PoleValidationsList(
                      api: widget.api,
                      items: _validations!.poleValidations,
                      onChanged: _load,
                    ),
                    _PuzzletValidationsList(
                      api: widget.api,
                      items: _validations!.puzzletValidations,
                      onChanged: _load,
                    ),
                  ]),
      ),
    );
  }
}

class _PoleValidationsList extends StatelessWidget {
  final PolesApi api;
  final List<PoleValidationModel> items;
  final Future<void> Function() onChanged;

  const _PoleValidationsList({
    required this.api,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Nothing assigned to you yet.'));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final v = items[i];
        return ListTile(
          title: Row(
            children: [
              Expanded(child: Text(v.pole?.label ?? v.pole?.barcode ?? v.poleId)),
              StatusBadge(
                label: validationStatusLabel(v.status),
                color: statusColorFor(v.status.name),
              ),
            ],
          ),
          subtitle: Text(
            '${v.pole?.barcode ?? ''} · ${v.comments.length} comment${v.comments.length == 1 ? '' : 's'}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final changed = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => PoleValidationDetailRoute(api: api, validation: v),
              ),
            );
            if (changed == true) await onChanged();
          },
        );
      },
    );
  }
}

class _PuzzletValidationsList extends StatelessWidget {
  final PolesApi api;
  final List<PuzzletValidationModel> items;
  final Future<void> Function() onChanged;

  const _PuzzletValidationsList({
    required this.api,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Nothing assigned to you yet.'));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final v = items[i];
        return ListTile(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  v.puzzlet?.instructions ?? v.puzzletId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadge(
                label: validationStatusLabel(v.status),
                color: statusColorFor(v.status.name),
              ),
            ],
          ),
          subtitle: Text(
            'Difficulty ${v.puzzlet?.difficulty ?? '?'} · ${v.comments.length} comment${v.comments.length == 1 ? '' : 's'}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final changed = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) =>
                    PuzzletValidationDetailRoute(api: api, validation: v),
              ),
            );
            if (changed == true) await onChanged();
          },
        );
      },
    );
  }
}
