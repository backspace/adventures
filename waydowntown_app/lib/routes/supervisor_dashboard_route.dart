import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/specification_validation.dart';
import 'package:waydowntown/routes/review_validation_route.dart';
import 'package:waydowntown/widgets/assign_validator_widget.dart';
import 'package:yaml/yaml.dart';

class SupervisorDashboardRoute extends StatefulWidget {
  final Dio dio;

  const SupervisorDashboardRoute({super.key, required this.dio});

  @override
  State<SupervisorDashboardRoute> createState() =>
      _SupervisorDashboardRouteState();
}

class _SupervisorDashboardRouteState extends State<SupervisorDashboardRoute>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SpecificationValidation> _validations = [];
  List<Map<String, dynamic>> _unvalidatedSpecs = [];
  YamlMap? _concepts;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final yamlString = await DefaultAssetBundle.of(context)
          .loadString('assets/concepts.yaml');
      _concepts = loadYaml(yamlString);

      final validationsResponse = await widget.dio
          .get('/waydowntown/specification-validations/supervise');
      final specsResponse =
          await widget.dio.get('/waydowntown/specifications');

      final validationsData =
          validationsResponse.data['data'] as List<dynamic>;
      final validationsIncluded =
          (validationsResponse.data['included'] as List<dynamic>?) ?? [];

      final validations = validationsData
          .map((json) =>
              SpecificationValidation.fromJson(json, validationsIncluded))
          .toList();

      // Find spec IDs that already have validations
      final validatedSpecIds =
          validations.map((v) => v.specification?.id).whereType<String>().toSet();

      // Build unvalidated specs list
      final allSpecs = specsResponse.data['data'] as List<dynamic>;
      final specsIncluded =
          (specsResponse.data['included'] as List<dynamic>?) ?? [];
      final unvalidated = allSpecs
          .where((s) => !validatedSpecIds.contains(s['id']))
          .map((s) {
            final creatorId =
                s['relationships']?['creator']?['data']?['id'] as String?;
            String? creatorName;
            if (creatorId != null) {
              final creatorJson = specsIncluded.cast<Map<String, dynamic>?>().firstWhere(
                (item) => item?['type'] == 'users' && item?['id'] == creatorId,
                orElse: () => null,
              );
              creatorName = creatorJson?['attributes']?['name'] as String? ??
                  creatorJson?['attributes']?['email'] as String?;
            }
            final regionId =
                s['relationships']?['region']?['data']?['id'] as String?;
            String? regionName;
            if (regionId != null) {
              final regionJson = specsIncluded.cast<Map<String, dynamic>?>().firstWhere(
                (item) => item?['type'] == 'regions' && item?['id'] == regionId,
                orElse: () => null,
              );
              regionName = regionJson?['attributes']?['name'] as String?;
            }
            return {
              'id': s['id'] as String,
              'concept': s['attributes']['concept'] as String? ?? 'Unknown',
              'start_description':
                  s['attributes']['start_description'] as String?,
              'task_description':
                  s['attributes']['task_description'] as String?,
              'creator_name': creatorName,
              'region_name': regionName,
            };
          })
          .toList();

      setState(() {
        _validations = validations;
        _unvalidatedSpecs = unvalidated;
        _isLoading = false;
      });
    } catch (e) {
      talker.error('Error fetching data: $e');
      setState(() {
        _error = 'Failed to load data';
        _isLoading = false;
      });
    }
  }

  List<SpecificationValidation> _filterByTab(int tabIndex) {
    switch (tabIndex) {
      case 0: // Pending review
        return _validations
            .where((v) => v.status == 'submitted')
            .toList();
      case 1: // Active
        return _validations
            .where(
                (v) => v.status == 'assigned' || v.status == 'in_progress')
            .toList();
      case 2: // Completed
        return _validations
            .where(
                (v) => v.status == 'accepted' || v.status == 'rejected')
            .toList();
      default:
        return _validations;
    }
  }

  String _conceptName(String? concept) {
    if (concept == null) return 'Unknown';
    final info = _concepts?[concept];
    if (info is YamlMap && info['name'] != null) {
      return info['name'] as String;
    }
    return concept;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'submitted':
        return Colors.purple;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _assignValidator(Map<String, dynamic> spec) async {
    final conceptDisplay = _conceptName(spec['concept']);
    final label =
        '$conceptDisplay${spec['start_description'] != null ? ' - ${spec['start_description']}' : ''}';
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignValidatorRoute(
          dio: widget.dio,
          specificationId: spec['id'],
          specificationLabel: label,
        ),
      ),
    );
    if (result == true) _fetchData();
  }

  Widget _buildValidationList(List<SpecificationValidation> validations) {
    if (validations.isEmpty) {
      return const Center(child: Text('No validations'));
    }

    return ListView.builder(
      itemCount: validations.length,
      itemBuilder: (context, index) {
        final validation = validations[index];
        final spec = validation.specification;
        final regionName = spec?.region?.name;
        final subtitleParts = <String>[
          'Validator: ${validation.validatorName ?? 'Unknown'}',
          if (regionName != null) regionName,
        ];
        return ListTile(
          title: Text(_conceptName(spec?.concept)),
          subtitle: Text(subtitleParts.join('\n')),
          isThreeLine: subtitleParts.length > 1,
          trailing: Chip(
            label: Text(
              validation.status.replaceAll('_', ' '),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            backgroundColor: _statusColor(validation.status),
          ),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReviewValidationRoute(
                  dio: widget.dio,
                  validation: validation,
                ),
              ),
            );
            _fetchData();
          },
        );
      },
    );
  }

  Widget _buildUnvalidatedList() {
    if (_unvalidatedSpecs.isEmpty) {
      return const Center(child: Text('All specifications have validations'));
    }

    return ListView.builder(
      itemCount: _unvalidatedSpecs.length,
      itemBuilder: (context, index) {
        final spec = _unvalidatedSpecs[index];
        final description = spec['start_description'] ??
            spec['task_description'] ??
            'No description';
        final creatorName = spec['creator_name'];
        final regionName = spec['region_name'];
        final subtitleParts = <String>[
          if (creatorName != null) 'by $creatorName',
          if (regionName != null) regionName,
          description,
        ];
        return ListTile(
          title: Text(_conceptName(spec['concept'])),
          subtitle: Text(
            subtitleParts.join('\n'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: subtitleParts.length > 1,
          trailing: IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Assign validator',
            onPressed: () => _assignValidator(spec),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(
                text:
                    'Unvalidated (${_isLoading ? '...' : _unvalidatedSpecs.length})'),
            Tab(
                text:
                    'Pending Review (${_isLoading ? '...' : _filterByTab(0).length})'),
            Tab(
                text:
                    'Active (${_isLoading ? '...' : _filterByTab(1).length})'),
            Tab(
                text:
                    'Completed (${_isLoading ? '...' : _filterByTab(2).length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildUnvalidatedList(),
                    _buildValidationList(_filterByTab(0)),
                    _buildValidationList(_filterByTab(1)),
                    _buildValidationList(_filterByTab(2)),
                  ],
                ),
    );
  }
}
