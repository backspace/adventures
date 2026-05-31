import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/test_session.dart';
import 'package:poles/routes/home_route.dart';

/// Landing screen for test play. Lets a validator/supervisor start a new
/// session or resume a recent one. Once a session is selected we push a
/// HomeRoute wired with a TestPlayPolesApi pointed at the session id.
class TestPlayEntryRoute extends StatefulWidget {
  final PolesApi api;
  const TestPlayEntryRoute({super.key, required this.api});

  @override
  State<TestPlayEntryRoute> createState() => _TestPlayEntryRouteState();
}

class _TestPlayEntryRouteState extends State<TestPlayEntryRoute> {
  List<TestSession>? _sessions;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final sessions = await widget.api.listTestSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load sessions: $e';
        _busy = false;
      });
    }
  }

  Future<void> _startSession() async {
    setState(() => _busy = true);
    try {
      final now = DateTime.now().toLocal();
      final stamp =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final session = await widget.api.createTestSession(name: stamp);
      if (!mounted) return;
      _enterSession(session);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not start session: $e';
      });
    }
  }

  void _enterSession(TestSession session) {
    final testApi = TestPlayPolesApi(widget.api.dio, session.id);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeRoute(api: testApi, testSession: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Test play')),
      body: _busy && _sessions == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Rehearse gameplay end-to-end. Captures and attempts in '
                    'a test session are recorded separately and do not affect '
                    'the real game.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _startSession,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start new session'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  Text('Recent sessions',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Expanded(
                    child: sessions.isEmpty
                        ? const Text('No prior sessions yet.')
                        : ListView.separated(
                            itemCount: sessions.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final s = sessions[i];
                              return ListTile(
                                title: Text(s.name ?? s.id),
                                subtitle: Text(s.isActive
                                    ? 'Active'
                                    : 'Ended ${s.endedAt}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _enterSession(s),
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
