import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/routes/author/capture_pole_route.dart';
import 'package:poles/routes/author/capture_puzzlet_route.dart';
import 'package:poles/routes/author/my_drafts_route.dart';

class AuthorRoute extends StatelessWidget {
  final PolesApi api;
  const AuthorRoute({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Author')),
      body: ListView(
        children: [
          _Tile(
            icon: Icons.qr_code_2,
            title: 'Capture a pole',
            subtitle: 'Scan the barcode and record where it is.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CapturePoleRoute(api: api)),
            ),
          ),
          _Tile(
            icon: Icons.edit_note,
            title: 'Submit a puzzlet',
            subtitle: 'Write a question and answer for any pole.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CapturePuzzletRoute(api: api)),
            ),
          ),
          _Tile(
            icon: Icons.list_alt,
            title: 'My drafts',
            subtitle: 'Review what you\'ve submitted.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MyDraftsRoute(api: api)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 32),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
