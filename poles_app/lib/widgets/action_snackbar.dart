import 'package:flutter/material.dart';

/// Shows a [SnackBar] and forces it to dismiss after [duration],
/// regardless of Flutter's internal timer. We observed action-bearing
/// snackbars on iOS sometimes failing to auto-dismiss even when none of
/// the usual accessibility flags (`accessibleNavigation`,
/// `disableAnimations`, etc.) are set, so this works around that by
/// explicitly closing the controller after [duration]. The action button
/// inside the snackbar continues to work as long as the user taps it
/// before the timer fires.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
    showActionSnackBar(
  ScaffoldMessengerState messenger,
  SnackBar snackBar, {
  Duration duration = const Duration(seconds: 6),
}) {
  final controller = messenger.showSnackBar(snackBar);
  Future.delayed(duration, () {
    try {
      controller.close();
    } catch (_) {
      // Already closed (action tapped, dismissed by swipe, route popped).
    }
  });
  return controller;
}
