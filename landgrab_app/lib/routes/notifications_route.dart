import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/models/notification.dart';
import 'package:landgrab/widgets/landgrab_app_bar.dart';

/// The team's notification history, newest first. Opening this
/// screen marks everything read server-side — read state is shared
/// across the team, so one member catching up clears the badge for
/// both. Unread entries keep their highlight for the current visit
/// so the reader can still see what's new.
class NotificationsRoute extends StatefulWidget {
  final LandgrabApi api;
  const NotificationsRoute({super.key, required this.api});

  @override
  State<NotificationsRoute> createState() => _NotificationsRouteState();
}

class _NotificationsRouteState extends State<NotificationsRoute> {
  List<LandgrabNotification>? _notifications;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final result = await widget.api.listNotifications();
      if (!mounted) return;
      setState(() => _notifications = result.notifications);
      if (result.unread > 0) {
        // Fire-and-forget; the local list keeps its unread highlights.
        widget.api.markNotificationsRead().catchError((_) {});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = NotificationStrings.couldNotLoad(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LandgrabAppBar(title: NotificationStrings.title),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : _notifications == null
              ? const Center(child: CircularProgressIndicator())
              : _notifications!.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          NotificationStrings.empty,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _notifications!.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final n = _notifications![index];
                          final poleId = n.metadata['pole_id'] as String?;
                          // Attack / pole-lost notifications point at a stake;
                          // offer a jump to it — pop back to the map with its id.
                          final canView = poleId != null &&
                              (n.type == 'attack' || n.type == 'pole_lost');
                          return _NotificationTile(
                            key: ValueKey(n.id),
                            notification: n,
                            onToggleRead: () => _toggleRead(n),
                            onViewOnMap: canView
                                ? () => Navigator.of(context).pop(poleId)
                                : null,
                          );
                        },
                      ),
                    ),
    );
  }

  /// Swipe toggles read/unread. Optimistic — flip locally, then tell
  /// the server; revert on failure. Team-scoped read state, so this
  /// also changes what teammates see on their next refresh.
  Future<void> _toggleRead(LandgrabNotification n) async {
    final wantRead = n.unread; // swiping an unread one marks it read
    final i = _notifications!.indexWhere((x) => x.id == n.id);
    if (i < 0) return;
    setState(() => _notifications![i] = n.withRead(wantRead));
    try {
      await widget.api.setNotificationRead(n.id, wantRead);
    } catch (_) {
      if (!mounted) return;
      setState(() => _notifications![i] = n); // revert
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(NotificationStrings.toggleFailed)),
      );
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final LandgrabNotification notification;
  final VoidCallback onToggleRead;
  // Non-null when the notification points at a stake — renders a
  // "View on map" button (and makes the row tappable) that returns to
  // the map focused on it.
  final VoidCallback? onViewOnMap;
  const _NotificationTile({
    super.key,
    required this.notification,
    required this.onToggleRead,
    this.onViewOnMap,
  });

  @override
  Widget build(BuildContext context) {
    // Dismissible gives the familiar iOS-Mail swipe-right gesture;
    // confirmDismiss returns false so the row snaps back instead of
    // being removed — the swipe just toggles read/unread.
    final markingRead = notification.unread;
    return Dismissible(
      key: ValueKey('dismiss-${notification.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onToggleRead();
        return false;
      },
      background: Container(
        color: Theme.of(context).colorScheme.primary,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              markingRead
                  ? Icons.mark_email_read_outlined
                  : Icons.mark_email_unread_outlined,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              markingRead
                  ? NotificationStrings.markRead
                  : NotificationStrings.markUnread,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
      child: _tile(context),
    );
  }

  Widget _tile(BuildContext context) {
    final tile = ListTile(
      leading: SizedBox(
        width: 36,
        height: 36,
        child: Icon(_icon, color: _color),
      ),
      title: Text(
        notification.body,
        style: notification.unread
            ? const TextStyle(fontWeight: FontWeight.bold)
            : null,
      ),
      subtitle: Text(_subtitle),
      onTap: onViewOnMap,
      trailing: notification.unread
          ? Icon(Icons.circle,
              size: 10, color: Theme.of(context).colorScheme.primary)
          : null,
    );
    if (onViewOnMap == null) return tile;
    // Explicit affordance beneath the row (aligned under the text) as well
    // as the whole-row tap, so the jump-to-map is discoverable.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tile,
        Padding(
          padding: const EdgeInsets.only(left: 68, bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onViewOnMap,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text(NotificationStrings.viewOnMap),
            ),
          ),
        ),
      ],
    );
  }

  /// Organiser messages carry their storyline sender; gameplay
  /// notifications' bodies already name the acting team.
  String get _subtitle {
    final sender = notification.metadata['sender_name'] as String?;
    final time = _relativeTime(notification.insertedAt);
    return sender == null ? time : '$sender · $time';
  }

  IconData get _icon => switch (notification.type) {
        'attack' => Icons.warning_amber_outlined,
        'pole_lost' => Icons.flag_outlined,
        'message' => Icons.mail_outline,
        _ => Icons.notifications_none,
      };

  Color? get _color => switch (notification.type) {
        'attack' => Colors.orange,
        'pole_lost' => Colors.red,
        _ => null,
      };

  static String _relativeTime(DateTime? when) {
    if (when == null) return '';
    final elapsed = DateTime.now().toUtc().difference(when);
    if (elapsed.inMinutes < 1) return NotificationStrings.justNow;
    if (elapsed.inHours < 1) {
      return NotificationStrings.minutesAgo(elapsed.inMinutes);
    }
    if (elapsed.inDays < 1) {
      return NotificationStrings.hoursAgo(elapsed.inHours);
    }
    return NotificationStrings.daysAgo(elapsed.inDays);
  }
}
