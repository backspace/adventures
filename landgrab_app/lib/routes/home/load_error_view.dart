import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:landgrab/l10n/player_strings.dart';

/// Shown in place of the map when the initial load fails. Gives a calm
/// message with the recovery ladder the failure usually needs — retry first,
/// log out if that doesn't help — plus a collapsible raw-error view (with
/// copy) so a stuck player can read/report the real cause.
class LoadErrorView extends StatefulWidget {
  final String message;
  final String? detail;
  final Future<void> Function() onRetry;
  final Future<void> Function() onLogout;

  const LoadErrorView({
    super.key,
    required this.message,
    required this.detail,
    required this.onRetry,
    required this.onLogout,
  });

  @override
  State<LoadErrorView> createState() => _LoadErrorViewState();
}

class _LoadErrorViewState extends State<LoadErrorView> {
  bool _showDetail = false;
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _retrying ? null : _retry,
              icon: _retrying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: const Text(GameplayStrings.loadTryAgain),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _retrying ? null : () => widget.onLogout(),
              icon: const Icon(Icons.logout),
              label: const Text(GameplayStrings.logOut),
            ),
            if (widget.detail != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _showDetail = !_showDetail),
                child: Text(_showDetail
                    ? GameplayStrings.loadHideDetails
                    : GameplayStrings.loadShowDetails),
              ),
              if (_showDetail)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: widget.detail!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text(GameplayStrings.loadDetailsCopied),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text(GameplayStrings.loadCopyDetails),
                        ),
                      ),
                      SelectableText(
                        widget.detail!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
