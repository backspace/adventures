/// Player-facing copy for the LANDGRAB app.
///
/// All strings shown to a regular participant — *not* role-holders
/// (author / validator / supervisor) — live here so they can be
/// tweaked in one place to match the in-storyline voice.
///
/// ## Voice conventions
///
/// LANDGRAB's site copy frames participants as **research subjects**
/// in a **simulation** run by visiting scholar **Sabuk** and their
/// **assistant** (aka the Subordinate). The device the participant
/// is using is diegetically "antiquated handheld Colonial Big Tech
/// technology." Copy here should feel of-a-piece with that framing:
///
///   * Refer to the participant as a subject, or address them
///     directly ("you") — never "player" / "user" / "gamer".
///   * The event is a "simulation" or "study session"; the app is
///     a "handheld terminal" or similar.
///   * Sabuk is the principal investigator; the assistant does the
///     admin work (email templates use this convention already —
///     see registrations/lib/registrations/mailer.ex).
///   * Be dry and vaguely academic; humour lands better under-
///     played. See the site's `landgrab.html.heex` for tone.
///   * Keep the strings short — mobile UI has limited room and
///     translations (if we ever add them) grow longer.
///
/// Role-holder UI (author map, validator flows, supervisor
/// dashboards) intentionally stays in plain English so authors
/// know what a button does at a glance without decoding storyline
/// wording. This file only covers regular-participant surfaces.
///
/// When adding a string:
///
///   1. Put it in the group that matches the surface it appears on.
///   2. Use a name that describes what the string IS, not what it
///      currently says. `signInButton`, not `justSignIn`.
///   3. Reference it from the widget as `LoginStrings.signInButton`.
library;

/// Login route (`routes/login_route.dart`).
class LoginStrings {
  LoginStrings._();

  static const appBarTitle = 'Sign in';
  static const emailLabel = 'Email';
  static const passwordLabel = 'Password';
  static const signInButton = 'Sign in';
  static const orDivider = 'or';
  static const signInWithGoogle = 'Sign in with Google';
  static const signInWithApple = 'Sign in with Apple';
  static const switchEnvironmentTooltip = 'Switch environment';
  static const switchButton = 'Switch';

  static const invalidCredentials = 'Invalid email or password';
  static const appleNoIdentityToken = 'Apple sign-in returned no identity token';
  static const appleSignInFailed = 'Apple sign-in failed';
  static String appleSignInFailedWith(String detail) =>
      'Apple sign-in failed: $detail';
  static String oauthCancelled(String provider) =>
      '$provider sign-in failed or was cancelled';
}

/// Pre-event home body (`_PreEventBody` in `routes/home_route.dart`).
class PreEventStrings {
  PreEventStrings._();

  static const notYetScheduled = 'Event not yet scheduled';
  static const openingCopy = 'Gameplay opens at start time. Until then, warm up.';
  static const countdownHeading = 'Event begins in';
  static const startingNow = 'starting now';

  static const toysHeading = 'Toys';
  static const barcodeToyLabel = 'Barcode scanner';
  static const barcodeToyTitle = 'Barcode toy';
  static const nfcToyLabel = 'NFC scanner';
  static const nfcToyTitle = 'NFC toy';
  static const noScansYet = 'No scans yet — tap to try';
  static String lastScan(String value) => 'Last: $value';
}

/// Gameplay home body — the map view (`routes/home_route.dart`).
class GameplayStrings {
  GameplayStrings._();

  static const scanFab = 'Scan';
  static const credits = 'Credits';
  static const details = 'Details';
  static const author = 'Author';
  static const validate = 'Validate';
  static const supervise = 'Supervise';
  static String couldNotLoadPoles(String error) =>
      'Could not load poles: $error';
}

/// Scan route (`routes/scan_route.dart`) — the barcode-scan camera
/// view + its outcome dialogs.
class ScanStrings {
  ScanStrings._();

  static const appBarTitle = 'Scan a pole';

  // Outcome snackbars
  static const poleFullyCaptured = 'This pole is fully captured.';
  static const noActivePuzzlet = 'No active puzzlet for this pole.';
  static String scanFailed(String detail) => 'Scan failed: $detail';

  // Unknown-barcode dialog
  static const unknownBarcodeTitle = 'Unknown barcode';
  static String unknownBarcodeBody(String barcode) =>
      '“$barcode” doesn\'t match any known pole. '
      'Make sure you scanned a pole\'s barcode and try again.';
  static const unknownBarcodeBack = 'Back to map';
  static const unknownBarcodeRetry = 'Try again';

  // Already-owner dialog
  static const alreadyOwnerTitle = 'Already yours';
  static String alreadyOwnerBody(String poleName) =>
      'Your team already owns $poleName. '
      'Wait for a rival to capture it before you can claim it again.';

  // Locked-out dialog
  static const lockedOutTitle = 'Out of guesses';
  static String lockedOutBody(String poleName) =>
      'Your team has used all guesses on the current puzzlet for $poleName. '
      'Wait for another team to capture it before you can try again.';

  // Own-creation dialog (authors can't capture their own content)
  static const ownCreationTitle = 'That one\'s yours';
  static String ownCreationBody(String poleName) =>
      'You authored $poleName, so you can\'t capture it — you know '
      'the answers. Leave it for the other teams.';

  // Generic acknowledge button used across the dialogs above.
  static const ok = 'OK';
}

/// Puzzlet-solving route (`routes/puzzlet_route.dart`).
class PuzzletStrings {
  PuzzletStrings._();

  static String attemptsRemaining(int n) => 'Attempts remaining: $n';
  static const previouslyTried = 'Already tried by your team:';
  static const answerLabel = 'Answer';
  static const answerLabelExact = 'Answer (exact match)';
  static const submitButton = 'Submit';

  // Barcode-answer flow
  static const scanBarcodeAnswerTitle = 'Scan the barcode';
  static const scanBarcodeAnswerButton = 'Scan barcode to answer';
  static const scanBarcodeAnswerHelp =
      'The answer is a barcode. Tap Scan to read it with the camera.';

  // NFC-answer flow
  static const scanNfcAnswerTitle = 'Scan the NFC tag';
  static const scanNfcAnswerButton = 'Tap NFC tag to answer';
  static const scanNfcAnswerHelp =
      'The answer is an NFC tag. Tap the button, then hold your phone '
      'near the tag.';

  // Outcome text
  static const correctAndLocked = 'Correct! Pole captured and now fully locked.';
  static const correctPoleCaptured = 'Correct! Pole captured.';
  static String incorrect(int remaining) =>
      'Incorrect. $remaining attempt(s) left.';
  static const lockedOut = 'Locked out — too many wrong answers.';
  static const alreadyCapturedByOther =
      'Another team captured this puzzlet first.';
  static const alreadyOwner =
      'Your team already owns this pole. Wait for a rival.';

  // Fallbacks for submissions that fail in ways the app doesn't
  // specifically model. When the server supplies an error detail,
  // that text is shown instead of these (server-side voice edits
  // happen in the Phoenix controllers).
  static String submissionFailedHttp(int statusCode) =>
      'Submission failed (HTTP $statusCode).';
  static const submissionFailedNetwork =
      'Submission failed — check your connection and try again.';
}

/// Details WebView route (`routes/details_webview_route.dart`).
class DetailsStrings {
  DetailsStrings._();

  static const appBarTitle = 'Details';
  static const reloadTooltip = 'Reload';
  static const tryAgain = 'Try again';
  static String couldNotOpen(String detail) =>
      'Could not open your details page: $detail';
}

/// Credits page (`routes/credits_route.dart`).
class CreditsStrings {
  CreditsStrings._();

  static const appBarTitle = 'Credits';
  static const acknowledgmentsHeading = 'Acknowledgments';
  static const placeholderCopy =
      'Content to come — a proper credits list, thanks, and '
      'library acknowledgments will land here before launch.';
  static const envSwitcherUnlocked = 'Environment switcher unlocked.';
}
