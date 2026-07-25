import 'dart:async';

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

  /// Live notification stream (the map socket's). When a notification arrives
  /// while this screen is open, the list refreshes in place — so tapping a
  /// toast's "View" while already here updates the list rather than doing
  /// nothing. Null in contexts without a socket (e.g. tests).
  final Stream<LandgrabNotification>? incoming;

  const NotificationsRoute({super.key, required this.api, this.incoming});

  @override
  State<NotificationsRoute> createState() => _NotificationsRouteState();
}

class _NotificationsRouteState extends State<NotificationsRoute> {
  List<LandgrabNotification>? _notifications;
  String? _error;
  StreamSubscription<LandgrabNotification>? _incomingSub;
  // Invite whose answer is in flight — disables its buttons meanwhile.
  String? _respondingId;

  // Fallback poll in case the live channel silently stops delivering (it's
  // behaved lately, but it has failed us before). Reset after every load, so
  // it only fires once the channel has actually been quiet this long — while
  // notifications are flowing over the socket it never runs.
  static const _idlePollInterval = Duration(minutes: 1);
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // Refresh when a new notification lands while we're open. Reload rather
    // than splice the one event, so read-state and ordering stay authoritative.
    // Silent: a socket-triggered reload that fails must not blank the list.
    _incomingSub = widget.incoming?.listen((_) {
      if (mounted) _refresh(surfaceError: false);
    });
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Initial load and pull-to-refresh: surface load errors in place of the
  /// list, since there's nothing (or a deliberate retry) behind them.
  Future<void> _load() => _refresh(surfaceError: true);

  Future<void> _refresh({required bool surfaceError}) async {
    if (surfaceError) setState(() => _error = null);
    try {
      final result = await widget.api.listNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = result.notifications;
        _error = null; // a good load clears any stale error banner
      });
      if (result.unread > 0) {
        // Fire-and-forget; the local list keeps its unread highlights.
        widget.api.markNotificationsRead().catchError((_) {});
      }
    } catch (e) {
      if (!mounted) return;
      // A background refresh (poll / socket event) that fails leaves the
      // last-known list untouched — a transient network blip shouldn't blank
      // the screen. Only the initial load (or an empty state) surfaces it.
      if (surfaceError || _notifications == null) {
        setState(() => _error = NotificationStrings.couldNotLoad(e.toString()));
      }
    } finally {
      if (mounted) _scheduleIdlePoll();
    }
  }

  void _scheduleIdlePoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer(_idlePollInterval, () {
      if (!mounted) return;
      // Don't clobber an in-flight invite answer; check back next interval.
      if (_respondingId != null) {
        _scheduleIdlePoll();
        return;
      }
      _refresh(surfaceError: false);
    });
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
                          // Unanswered liberation invite — offer the
                          // accept/decline pair right in the row.
                          final canRespond = n.type == 'liberation_invite' &&
                              n.response == null;
                          return _NotificationTile(
                            key: ValueKey(n.id),
                            notification: n,
                            onToggleRead: () => _toggleRead(n),
                            onViewOnMap: canView
                                ? () => Navigator.of(context).pop(poleId)
                                : null,
                            onRespond: canRespond && _respondingId == null
                                ? (response) => _respond(n, response)
                                : null,
                            responding: _respondingId == n.id,
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

  /// Answer the liberation invite. Not optimistic — the first answer
  /// binds the whole team, so wait for the server's word. The API call
  /// already resolves a teammate-beat-us 409 to their recorded answer;
  /// if what comes back isn't what was tapped, say so.
  Future<void> _respond(LandgrabNotification n, String response) async {
    setState(() => _respondingId = n.id);
    try {
      final recorded = await widget.api.respondToNotification(n.id, response);
      if (!mounted) return;
      final i = _notifications!.indexWhere((x) => x.id == n.id);
      setState(() {
        if (i >= 0) _notifications![i] = n.withResponse(recorded);
      });
      if (recorded != response) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(NotificationStrings.inviteAlreadyAnswered)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(NotificationStrings.inviteFailed)),
      );
    } finally {
      if (mounted) setState(() => _respondingId = null);
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
  // Non-null while a liberation invite awaits the team's answer —
  // renders the accept/decline pair. Null once answered (the recorded
  // answer shows instead) or while another answer is in flight.
  final void Function(String response)? onRespond;
  // True while THIS invite's answer is in flight — shows a spinner in
  // place of the buttons.
  final bool responding;
  const _NotificationTile({
    super.key,
    required this.notification,
    required this.onToggleRead,
    this.onViewOnMap,
    this.onRespond,
    this.responding = false,
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
    final footer = _footer(context);
    if (footer == null) return tile;
    // Explicit affordance beneath the row (aligned under the text) as well
    // as the whole-row tap, so it's discoverable.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tile,
        Padding(
          padding: const EdgeInsets.only(left: 68, bottom: 8),
          child: Align(alignment: Alignment.centerLeft, child: footer),
        ),
      ],
    );
  }

  /// The action area beneath the tile: jump-to-map for stake
  /// notifications, the answer buttons (or recorded answer) for the
  /// liberation invite, nothing otherwise.
  Widget? _footer(BuildContext context) {
    if (onViewOnMap != null) {
      return TextButton.icon(
        onPressed: onViewOnMap,
        icon: const Icon(Icons.map_outlined, size: 18),
        label: const Text(NotificationStrings.viewOnMap),
      );
    }
    if (responding) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (onRespond != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: () => onRespond!('accepted'),
            child: const Text(NotificationStrings.inviteAccept),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => onRespond!('declined'),
            child: const Text(NotificationStrings.inviteDecline),
          ),
        ],
      );
    }
    if (notification.type == 'liberation_invite' &&
        notification.response != null) {
      final accepted = notification.response == 'accepted';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            accepted ? Icons.handshake_outlined : Icons.do_not_disturb_alt,
            size: 18,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Text(
            accepted
                ? NotificationStrings.inviteAccepted
                : NotificationStrings.inviteDeclined,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }
    return null;
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
        'liberation_invite' => Icons.handshake_outlined,
        'liberation_joined' => Icons.groups_outlined,
        // Supervisor-only: a team ran out of guesses and is stuck.
        'team_stuck' => Icons.support_agent_outlined,
        _ => Icons.notifications_none,
      };

  Color? get _color => switch (notification.type) {
        'attack' => Colors.orange,
        'pole_lost' => Colors.red,
        'liberation_invite' => Colors.purple,
        'liberation_joined' => Colors.purple,
        'team_stuck' => Colors.teal,
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
