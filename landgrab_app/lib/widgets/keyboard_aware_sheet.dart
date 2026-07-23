import 'package:flutter/material.dart';

/// Opens a modal bottom sheet whose content always stays above the on-screen
/// keyboard. Use it to edit text on screens that aren't themselves scrollable
/// — the map-based supervisor tabs, say — where a focused field would
/// otherwise end up hidden behind the keyboard (notably on iPad, whose
/// keyboard is tall).
///
/// The mechanics that solve that live here, once: the sheet is
/// [isScrollControlled] so it can grow tall enough, its body scrolls, and it
/// pads its bottom by the live keyboard inset so the focused field rides above
/// the keyboard. Callers supply only the body via [builder] and pop the sheet
/// with whatever result they need (or nothing).
Future<T?> showKeyboardAwareSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // Leave a little headroom; the scroll view + keyboard padding handle the
    // rest, so even a tall editor with the keyboard up stays usable.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.9,
    ),
    builder: (sheetContext) {
      // Read inside the builder so the sheet rebuilds as the keyboard opens
      // and closes — that's what keeps the body lifted above it.
      final keyboard = MediaQuery.of(sheetContext).viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: builder(sheetContext),
        ),
      );
    },
  );
}
