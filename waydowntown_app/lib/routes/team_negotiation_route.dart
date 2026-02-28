import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/team_negotiation.dart';
import 'package:waydowntown/widgets/team_form_widget.dart';
import 'package:waydowntown/widgets/team_status_widget.dart';

class TeamNegotiationRoute extends StatefulWidget {
  final Dio dio;

  const TeamNegotiationRoute({super.key, required this.dio});

  @override
  State<TeamNegotiationRoute> createState() => _TeamNegotiationRouteState();
}

class _TeamNegotiationRouteState extends State<TeamNegotiationRoute> {
  TeamNegotiation? _negotiation;
  bool _isLoading = true;
  String? _error;
  final TextEditingController _teamEmailsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTeamNegotiation();
  }

  @override
  void dispose() {
    _teamEmailsController.dispose();
    super.dispose();
  }

  void _addEmailToTeam(String email) {
    final currentText = _teamEmailsController.text.trim();
    final emails = currentText.isEmpty ? <String>[] : currentText.split(RegExp(r'\s+'));
    if (!emails.contains(email)) {
      emails.add(email);
      _teamEmailsController.text = emails.join(' ');
    }
  }

  Future<void> _fetchTeamNegotiation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await widget.dio.get('/waydowntown/team-negotiation');
      if (response.statusCode == 200) {
        final negotiation = TeamNegotiation.fromJson(response.data);
        _teamEmailsController.text = negotiation.teamEmails ?? '';
        setState(() {
          _negotiation = negotiation;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load team negotiation data');
      }
    } catch (e) {
      talker.error('Error fetching team negotiation: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchTeamNegotiation,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_negotiation == null) {
      return const Center(child: Text('No data available'));
    }

    // If user has an assigned team, show team details
    if (_negotiation!.team != null) {
      return _buildTeamDetails();
    }

    // Otherwise show negotiation UI
    return RefreshIndicator(
      onRefresh: _fetchTeamNegotiation,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TeamStatusWidget(
              negotiation: _negotiation!,
              onAddEmail: _addEmailToTeam,
            ),
            const SizedBox(height: 24),
            TeamFormWidget(
              dio: widget.dio,
              negotiation: _negotiation!,
              teamEmailsController: _teamEmailsController,
              onSaved: _fetchTeamNegotiation,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamDetails() {
    final team = _negotiation!.team!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Team',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (team.notes != null && team.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(team.notes!),
                  ],
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Members',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...team.members.map((member) => ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(member.name ?? member.email),
                        subtitle:
                            member.name != null ? Text(member.email) : null,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
