import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/team_negotiation.dart';
import 'package:waydowntown/services/user_service.dart';

class TeamFormWidget extends StatefulWidget {
  final Dio dio;
  final TeamNegotiation negotiation;
  final VoidCallback onSaved;

  const TeamFormWidget({
    super.key,
    required this.dio,
    required this.negotiation,
    required this.onSaved,
  });

  @override
  State<TeamFormWidget> createState() => _TeamFormWidgetState();
}

class _TeamFormWidgetState extends State<TeamFormWidget> {
  late TextEditingController _teamEmailsController;
  late TextEditingController _proposedTeamNameController;
  int? _riskAversion;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _teamEmailsController =
        TextEditingController(text: widget.negotiation.teamEmails ?? '');
    _proposedTeamNameController =
        TextEditingController(text: widget.negotiation.proposedTeamName ?? '');
    _riskAversion = widget.negotiation.riskAversion;
  }

  @override
  void dispose() {
    _teamEmailsController.dispose();
    _proposedTeamNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final userId = await UserService.getUserId();
      final response = await widget.dio.post(
        '/fixme/me',
        data: {
          'data': {
            'type': 'users',
            'id': userId,
            'attributes': {
              'team_emails': _teamEmailsController.text,
              'proposed_team_name': _proposedTeamNameController.text,
              'risk_aversion': _riskAversion,
            }
          }
        },
        options: Options(headers: {
          'Accept': 'application/vnd.api+json',
          'Content-Type': 'application/vnd.api+json',
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Team preferences saved')),
          );
          widget.onSaved();
        }
      }
    } catch (e) {
      talker.error('Error saving team preferences: $e');
      setState(() {
        _error = 'Failed to save team preferences';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Team Preferences',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _teamEmailsController,
          decoration: const InputDecoration(
            labelText: 'Team member emails',
            helperText: 'Enter email addresses separated by spaces',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _proposedTeamNameController,
          decoration: const InputDecoration(
            labelText: 'Proposed team name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Risk aversion',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        RadioListTile<int>(
          title: const Text('Low risk (1)'),
          subtitle:
              const Text('Prefer challenges that are quicker and easier'),
          value: 1,
          groupValue: _riskAversion,
          onChanged: (value) => setState(() => _riskAversion = value),
        ),
        RadioListTile<int>(
          title: const Text('Medium risk (2)'),
          subtitle: const Text('Balanced mix of challenge and accessibility'),
          value: 2,
          groupValue: _riskAversion,
          onChanged: (value) => setState(() => _riskAversion = value),
        ),
        RadioListTile<int>(
          title: const Text('High risk (3)'),
          subtitle: const Text('Prefer more challenging and involved tasks'),
          value: 3,
          groupValue: _riskAversion,
          onChanged: (value) => setState(() => _riskAversion = value),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ),
      ],
    );
  }
}
