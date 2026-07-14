import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/organiser_message.dart';

/// Compose and send storyline messages from the organisers to every
/// team. Prewritten messages sit as drafts until their moment; the
/// compose sheet can also send immediately for on-the-spot ones.
/// Role-holder UI: plain English on purpose.
class OrganiserMessagesTab extends StatefulWidget {
  final LandgrabApi api;
  const OrganiserMessagesTab({super.key, required this.api});

  @override
  State<OrganiserMessagesTab> createState() => _OrganiserMessagesTabState();
}

class _OrganiserMessagesTabState extends State<OrganiserMessagesTab> {
  // SYSTEM is for out-of-character/mechanical announcements; a
  // future version may auto-send SYSTEM messages on a schedule
  // (event milestones etc.) — the server already accepts any
  // sender string, so that needs no schema change.
  static const senderPresets = ["Sabuk's assistant", 'Bedak', 'Sabuk', 'SYSTEM'];

  List<OrganiserMessage>? _messages;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final messages = await widget.api.listOrganiserMessages();
      if (mounted) setState(() => _messages = messages);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load messages: $e');
    }
  }

  Future<void> _compose() async {
    final result = await showModalBottomSheet<_ComposeResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ComposeSheet(presets: senderPresets),
    );
    if (result == null || !mounted) return;

    try {
      await widget.api.createOrganiserMessage(
        body: result.body,
        senderName: result.senderName,
        sendNow: result.sendNow,
      );
      await _load();
      if (mounted && result.sendNow) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sent to all teams.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _send(OrganiserMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send to all teams?'),
        content: Text('From ${message.senderName}:\n\n${message.body}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.api.sendOrganiserMessage(message.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sent to all teams.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Compose'),
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : _messages == null
              ? const Center(child: CircularProgressIndicator())
              : _messages!.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No messages yet. Compose prewritten ones here '
                          'and send each when its moment arrives.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: _messages!.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final message = _messages![index];
                          return ListTile(
                            leading: SizedBox(
                              width: 36,
                              height: 36,
                              child: Icon(
                                message.sent
                                    ? Icons.mark_email_read_outlined
                                    : Icons.drafts_outlined,
                                color: message.sent ? Colors.green : null,
                              ),
                            ),
                            title: Text(message.body),
                            subtitle: Text(
                              message.sent
                                  ? '${message.senderName} · sent'
                                  : '${message.senderName} · draft',
                            ),
                            trailing: message.sent
                                ? null
                                : FilledButton.tonal(
                                    onPressed: () => _send(message),
                                    child: const Text('Send'),
                                  ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _ComposeResult {
  final String body;
  final String senderName;
  final bool sendNow;
  _ComposeResult(this.body, this.senderName, this.sendNow);
}

class _ComposeSheet extends StatefulWidget {
  final List<String> presets;
  const _ComposeSheet({required this.presets});

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  static const _other = 'Other…';

  final _controller = TextEditingController();
  final _customSenderController = TextEditingController();
  late String _sender = widget.presets.first;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _customSenderController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _customSenderController.dispose();
    super.dispose();
  }

  String get _effectiveSender =>
      _sender == _other ? _customSenderController.text.trim() : _sender;

  bool get _valid =>
      _controller.text.trim().isNotEmpty && _effectiveSender.isNotEmpty;

  void _pop(bool sendNow) {
    Navigator.of(context)
        .pop(_ComposeResult(_controller.text.trim(), _effectiveSender, sendNow));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New message', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _sender,
            decoration: const InputDecoration(labelText: 'From'),
            items: [
              for (final preset in widget.presets)
                DropdownMenuItem(value: preset, child: Text(preset)),
              const DropdownMenuItem(value: _other, child: Text(_other)),
            ],
            onChanged: (value) => setState(() => _sender = value ?? _sender),
          ),
          if (_sender == _other) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customSenderController,
              decoration: const InputDecoration(
                labelText: 'Sender name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 8,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Message',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _valid ? () => _pop(false) : null,
                child: const Text('Save draft'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _valid ? () => _pop(true) : null,
                child: const Text('Send now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
