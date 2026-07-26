import 'package:flutter/material.dart';
import 'package:landgrab/l10n/player_strings.dart';

/// Entries in the home app bar's overflow menu. Role-gated tools and
/// occasional actions live here so the bar itself never overflows,
/// however many roles the signed-in user holds.
enum HomeMenuItem {
  author,
  validate,
  supervise,
  joinTeam,
  details,
  instructions,
  credits,
  localDataViewer,
  forgetLocalData,
  settings,
  logOut,
}

/// The home app bar's overflow menu. Builds the role-gated item list and
/// reports the chosen [HomeMenuItem] via [onSelected]; HomeRoute owns the
/// switch that acts on the choice.
class HomeMenu extends StatelessWidget {
  final bool isAuthor;
  final bool isValidator;
  final bool isSupervisor;
  final bool hasTeam;
  final bool preEvent;
  final bool hasLocalDataset;
  final String? accountEmail;
  final ValueChanged<HomeMenuItem> onSelected;

  const HomeMenu({
    super.key,
    required this.isAuthor,
    required this.isValidator,
    required this.isSupervisor,
    required this.hasTeam,
    required this.preEvent,
    this.hasLocalDataset = false,
    required this.accountEmail,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<HomeMenuItem>(
      tooltip: GameplayStrings.menuTooltip,
      onSelected: onSelected,
      itemBuilder: (context) => [
        if (!preEvent && isAuthor)
          _item(context, HomeMenuItem.author, Icons.edit_note,
              GameplayStrings.author),
        if (!preEvent && isValidator)
          _item(context, HomeMenuItem.validate, Icons.fact_check_outlined,
              GameplayStrings.validate),
        if (!preEvent && isSupervisor)
          _item(context, HomeMenuItem.supervise, Icons.supervisor_account,
              GameplayStrings.supervise),
        // Only while unteamed — once on a team "Join a team" reads wrong, and
        // hiding it avoids accidental mid-game switching. (People without a
        // team also get the banner on the map.)
        if (!hasTeam)
          _item(context, HomeMenuItem.joinTeam, Icons.group_add_outlined,
              JoinTeamStrings.appBarTitle),
        _item(context, HomeMenuItem.details, Icons.badge_outlined,
            GameplayStrings.details),
        _item(context, HomeMenuItem.instructions, Icons.menu_book_outlined,
            GameplayStrings.instructions),
        _item(context, HomeMenuItem.credits, Icons.info_outline,
            GameplayStrings.credits),
        // Appears once a dataset has been synced device-to-device; reopens the
        // offline browser over the stored (encrypted) content.
        if (hasLocalDataset)
          _item(context, HomeMenuItem.localDataViewer,
              Icons.folder_special_outlined, 'Local data viewer'),
        if (hasLocalDataset)
          _item(context, HomeMenuItem.forgetLocalData, Icons.delete_outline,
              'Forget local data'),
        // Settings is for everyone (it holds the light/dark toggle); the
        // environment switcher inside it stays gated by the 7-tap unlock,
        // checked within the route.
        _item(context, HomeMenuItem.settings, Icons.settings_outlined,
            GameplayStrings.settings),
        _item(
          context,
          HomeMenuItem.logOut,
          Icons.logout,
          GameplayStrings.logOut,
          // Always show which account you're signed in as, so it's never a
          // mystery who you're logged in with.
          subtitle: accountEmail,
        ),
      ],
    );
  }

  PopupMenuItem<HomeMenuItem> _item(
      BuildContext context, HomeMenuItem value, IconData icon, String label,
      {String? subtitle}) {
    return PopupMenuItem<HomeMenuItem>(
      value: value,
      child: Row(
        children: [
          // Explicit colour so the icon reads on the popup surface — without
          // it, it inherits the app bar's foreground (white) and vanishes on
          // the light menu background in light mode.
          Icon(icon,
              size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          if (subtitle == null)
            Text(label)
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
