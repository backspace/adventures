import 'package:flutter/material.dart';

/// Wraps [child] and paints an opaque cover whenever the app leaves the
/// foreground. This keeps sensitive content out of the iOS app-switcher
/// snapshot (captured as the app backgrounds) and off view during a quick
/// app switch. Wrap the routes that render decrypted content.
class SecureScreenGuard extends StatefulWidget {
  final Widget child;
  const SecureScreenGuard({super.key, required this.child});

  @override
  State<SecureScreenGuard> createState() => _SecureScreenGuardState();
}

class _SecureScreenGuardState extends State<SecureScreenGuard>
    with WidgetsBindingObserver {
  bool _covered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cover on anything other than fully-foreground. `inactive` fires *before*
    // iOS grabs the app-switcher snapshot, so the cover is in place in time.
    final cover = state != AppLifecycleState.resumed;
    if (cover != _covered) setState(() => _covered = cover);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_covered)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
