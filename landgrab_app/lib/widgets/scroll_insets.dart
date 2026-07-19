import 'package:flutter/widgets.dart';

/// Adds the device's bottom safe-area inset (the Android gesture/nav bar or
/// iOS home indicator) to a scroll view's [base] padding, so a form's last
/// element — usually the submit button — scrolls clear of the nav zone
/// instead of ending up underneath it on edge-to-edge Android.
///
/// Uses [MediaQueryData.padding] (not `viewPadding`) so it collapses to zero
/// while the keyboard is up and covering the nav area — no doubled gap under
/// the fields when typing.
EdgeInsets scrollInsets(
  BuildContext context, [
  EdgeInsets base = const EdgeInsets.all(20),
]) =>
    base.copyWith(bottom: base.bottom + MediaQuery.paddingOf(context).bottom);
