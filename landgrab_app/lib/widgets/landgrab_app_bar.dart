import 'package:flutter/material.dart';

/// App bar with the LANDGRAB house style: the title is always rendered
/// in uppercase (in the Anton display face set by the app theme). Use
/// this in place of a bare [AppBar] so every screen's header stays
/// all-caps from a single place — Flutter's [TextStyle] has no
/// text-transform, so the uppercasing has to live here rather than in
/// the theme's `appBarTheme`.
///
/// Covers the common cases (a string title plus optional actions, a
/// [bottom] such as a TabBar, and leading control). A screen that needs
/// a fully custom title widget can still use a bare [AppBar].
class LandgrabAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const LandgrabAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title.toUpperCase()),
      actions: actions,
      bottom: bottom,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
    );
  }
}
