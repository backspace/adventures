import 'package:flutter/material.dart';
import 'package:waydowntown/models/team_negotiation.dart';

class TeamStatusWidget extends StatelessWidget {
  final TeamNegotiation negotiation;
  final void Function(String email)? onAddEmail;

  const TeamStatusWidget({
    super.key,
    required this.negotiation,
    this.onAddEmail,
  });

  @override
  Widget build(BuildContext context) {
    if (negotiation.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Enter email addresses below to propose team members.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Team Status',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (negotiation.mutuals.isNotEmpty) ...[
          _buildSection(
            context,
            title: 'Confirmed Team Members',
            icon: Icons.check_circle,
            iconColor: Colors.green,
            items: negotiation.mutuals
                .map((m) => _MemberDisplay(
                      name: m.name ?? m.email,
                      email: m.name != null ? m.email : null,
                    ))
                .toList(),
          ),
        ],
        if (negotiation.proposers.isNotEmpty) ...[
          _buildSection(
            context,
            title: 'Want to Team With You',
            icon: Icons.person_add,
            iconColor: Colors.blue,
            items: negotiation.proposers
                .map((m) => _MemberDisplay(
                      name: m.name ?? m.email,
                      email: m.name != null ? m.email : null,
                      tappableEmail: m.email,
                    ))
                .toList(),
            hint: onAddEmail != null
                ? 'Tap to add their email to your team.'
                : 'Add their email to your team emails to confirm the connection.',
            onTap: onAddEmail,
          ),
        ],
        if (negotiation.proposees.isNotEmpty) ...[
          _buildSection(
            context,
            title: 'Waiting for Confirmation',
            icon: Icons.hourglass_empty,
            iconColor: Colors.orange,
            items: negotiation.proposees
                .map((p) => _MemberDisplay(
                      name: p.email,
                      subtitle: p.invited
                          ? 'Invited'
                          : (p.registered ? 'Registered' : 'Not registered'),
                    ))
                .toList(),
            hint: 'These people need to add your email to their team.',
          ),
        ],
        if (negotiation.invalids.isNotEmpty) ...[
          _buildSection(
            context,
            title: 'Invalid Entries',
            icon: Icons.error,
            iconColor: Colors.red,
            items: negotiation.invalids
                .map((i) => _MemberDisplay(name: i))
                .toList(),
            hint: 'These entries are not valid email addresses.',
          ),
        ],
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<_MemberDisplay> items,
    String? hint,
    void Function(String email)? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(
                hint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
              ),
            ],
            const SizedBox(height: 8),
            ...items.map((item) {
              final isTappable = onTap != null && item.tappableEmail != null;
              final content = Row(
                children: [
                  Icon(
                    isTappable ? Icons.add_circle_outline : Icons.person,
                    size: 16,
                    color: isTappable ? Colors.blue : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: isTappable
                              ? const TextStyle(color: Colors.blue)
                              : null,
                        ),
                        if (item.email != null)
                          Text(
                            item.email!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (item.subtitle != null)
                          Text(
                            item.subtitle!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                ],
              );

              if (isTappable) {
                return InkWell(
                  onTap: () => onTap(item.tappableEmail!),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: content,
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: content,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MemberDisplay {
  final String name;
  final String? email;
  final String? subtitle;
  final String? tappableEmail;

  _MemberDisplay({
    required this.name,
    this.email,
    this.subtitle,
    this.tappableEmail,
  });
}
