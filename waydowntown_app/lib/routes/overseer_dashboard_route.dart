import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/specification_validation.dart';
import 'package:waydowntown/routes/review_validation_route.dart';
import 'package:waydowntown/widgets/assign_validator_widget.dart';

class OverseerDashboardRoute extends StatefulWidget {
  final Dio dio;

  const OverseerDashboardRoute({super.key, required this.dio});

  @override
  State<OverseerDashboardRoute> createState() =>
      _OverseerDashboardRouteState();
}

class _OverseerDashboardRouteState extends State<OverseerDashboardRoute>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SpecificationValidation> _validations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchValidations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchValidations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await widget.dio
          .get('/waydowntown/specification-validations/oversee');

      if (response.statusCode == 200) {
        final data = response.data['data'] as List<dynamic>;
        final included =
            (response.data['included'] as List<dynamic>?) ?? [];
        setState(() {
          _validations = data
              .map((json) =>
                  SpecificationValidation.fromJson(json, included))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      talker.error('Error fetching validations: $e');
      setState(() {
        _error = 'Failed to load validations';
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

  Widget _buildList(List<SpecificationValidation> validations) {
    if (validations.isEmpty) {
      return const Center(child: Text('No validations'));
    }

    return ListView.builder(
      itemCount: validations.length,
      itemBuilder: (context, index) {
        final validation = validations[index];
        final spec = validation.specification;
        return ListTile(
          title: Text(spec?.concept ?? 'Unknown'),
          subtitle: Text(
            'Validator: ${validation.validatorName ?? 'Unknown'}',
          ),
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
            _fetchValidations();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overseer Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending Review'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showDialog(
            context: context,
            builder: (context) => AssignValidatorWidget(dio: widget.dio),
          );
          _fetchValidations();
        },
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(_filterByTab(0)),
                    _buildList(_filterByTab(1)),
                    _buildList(_filterByTab(2)),
                  ],
                ),
    );
  }
}
