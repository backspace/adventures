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
  static const serverUnreachable =
      'Can\'t reach the server. Check your connection (and VPN, if you '
      'use one) and try again.';
  static const loginFailed = 'Sign-in failed. Please try again.';
  static const appleNoIdentityToken =
      'Apple sign-in returned no identity token';
  static const appleSignInFailed = 'Apple sign-in failed';
  static String appleSignInFailedWith(String detail) =>
      'Apple sign-in failed: $detail';
  static String oauthCancelled(String provider) =>
      '$provider sign-in failed or was cancelled';

  static const noAccountPrompt = 'New here?';
  static const createAccountLink = 'Create an account';
  static const forgotPassword = 'Forgot password?';
}

/// Password-reset WebView (`routes/forgot_password_route.dart`), which
/// hosts the registrations site's public `/reset-password/new` page.
class ForgotPasswordStrings {
  ForgotPasswordStrings._();

  static const appBarTitle = 'Reset password';
  static const reloadTooltip = 'Reload';
  static const tryAgain = 'Try again';
  static String couldNotOpen(String detail) =>
      'Could not open the password-reset page: $detail';
}

/// Sign-up screen (`routes/register_route.dart`), for people arriving
/// without having registered ahead of time.
class RegisterStrings {
  RegisterStrings._();

  static const appBarTitle = 'Create account';
  static const intro =
      'Create an account with your email, then we\'ll get your details.';
  static const emailLabel = 'Email';
  static const passwordLabel = 'Password';
  static const createAccountButton = 'Create account';
  static const haveAccountPrompt = 'Already have an account?';
  static const signInLink = 'Sign in';

  static const serverUnreachable =
      'Can\'t reach the server. Check your connection (and VPN, if you '
      'use one) and try again.';
  static const failed = 'Couldn\'t create your account. Please try again.';
}

/// Pre-event home body (`_PreEventBody` in `routes/home_route.dart`).
class PreEventStrings {
  PreEventStrings._();

  static const notYetScheduled = 'Simulation not yet scheduled';
  static const openingCopy =
      'Simulation begins at start time. Until then, practice.';
  static const countdownHeading = 'Simulation begins in';
  static const startingNow = 'starting now';

  static const practiceHeading = 'Practice';
  static const barcodePracticeLabel = 'Barcode scanner';
  static const barcodePracticeTitle = 'Barcode practice';
  static const nfcPracticeLabel = 'NFC scanner';
  static const nfcPracticeTitle = 'NFC practice';
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
  static const refresh = 'Refresh';
  static const menuTooltip = 'Menu';
  static const logOut = 'Log out';
  static const notificationsTooltip = 'Notifications';

  // Active-puzzlet ("in progress") card + give-up flow.
  static const inProgressHeading = 'Your team is working on';
  static const resume = 'Open';
  static const giveUp = 'Give up';
  static const giveUpTitle = 'Give up on this relic?';
  static String giveUpBody(String poleName) =>
      'Your team will stop working on $poleName and can pick up a '
      'different zone. You can come back to this one later.';
  static const giveUpCancel = 'Keep working';
  static const giveUpConfirm = 'Give up';

  // Scan refused because the team already holds a puzzlet.
  static const atCapacityTitle = 'Already on a relic';
  static String atCapacityBody(String current) =>
      'Your team is already working on $current. Finish it or give it '
      'up before starting another.';

  // A rival captured the puzzlet your team was working on.
  static const puzzletTakenTryNext = 'Try the next one';

  // How many other teams are also on this pole (shown on the
  // in-progress card).
  static String othersHere(int n) => '$n other${n == 1 ? '' : 's'} here';
  static String couldNotLoadPoles(String error) =>
      'Could not load zones: $error';
}

/// Notification history (`routes/notifications_route.dart`).
class NotificationStrings {
  NotificationStrings._();

  static const title = 'Notifications';
  static const empty =
      'Nothing yet. When a rival team scans your stake or captures one of your '
      'zones, it shows up here.';
  static String couldNotLoad(String error) =>
      'Could not load notifications: $error';

  // Swipe-to-toggle read state.
  static const markRead = 'Mark read';
  static const markUnread = 'Mark unread';
  static const toggleFailed = 'Could not update — check your connection.';

  // Catch-up toast on the map when unread arrived while the app
  // wasn't live (cold boot, backgrounded, socket outage).
  static String whileAway(int n) => n == 1
      ? '1 notification while you were away'
      : '$n notifications while you were away';
  static const viewAction = 'View';

  // Relative timestamps for the list entries.
  static const justNow = 'just now';
  static String minutesAgo(int m) => '${m}m ago';
  static String hoursAgo(int h) => '${h}h ago';
  static String daysAgo(int d) => '${d}d ago';
}

/// Scan route (`routes/scan_route.dart`) — the barcode-scan camera
/// view + its outcome dialogs.
class ScanStrings {
  ScanStrings._();

  static const appBarTitle = 'Scan a zone barcode';

  // Outcome snackbars
  static const poleFullyCaptured = 'This zone is fully captured.';
  static const noActivePuzzlet = 'No active relics for this zone.';
  static String scanFailed(String detail) => 'Scan failed: $detail';

  // Unknown-barcode dialog
  static const unknownBarcodeTitle = 'Unknown barcode';
  static String unknownBarcodeBody(String barcode) =>
      '“$barcode” doesn\'t match any known zone. '
      'Make sure you scanned a zone\'s barcode and try again.';
  static const unknownBarcodeBack = 'Back to map';
  static const unknownBarcodeRetry = 'Try again';

  // Already-owner dialog
  static const alreadyOwnerTitle = 'Already yours';
  static String alreadyOwnerBody(String poleName) =>
      'Your team already claims $poleName. '
      'Wait for a rival to capture it before you can claim it again.';

  // Locked-out dialog
  static const lockedOutTitle = 'Out of guesses';
  static String lockedOutBody(String poleName) =>
      'Your team has used all attempts on the current relic for $poleName. '
      'Wait for another team to capture it before you can try again.';

  // Own-creation dialog (authors can't capture their own content)
  static const ownCreationTitle = 'That one\'s yours';
  static String ownCreationBody(String poleName) =>
      'You authored $poleName, so you can\'t capture it. Leave it for the other teams.';

  // Outside-the-endgame-boundary dialog. The boundary itself is
  // deliberately invisible — poles it has passed vanish from the
  // map — so the copy points at remaining poles, not at a circle.
  static const outsideZoneTitle = 'Out of range';
  static String outsideZoneBody(String poleName) =>
      'The simulation has withdrawn $poleName — it can no longer be '
      'claimed. Only zone stakes still on your map remain in play.';

  // Generic acknowledge button used across the dialogs above.
  static const ok = 'OK';
}

/// Puzzlet-solving route (`routes/puzzlet_route.dart`).
class PuzzletStrings {
  PuzzletStrings._();

  static const titlePrefix = 'Pole';
  static String attemptsRemaining(int n) => 'Attempts remaining: $n';
  static String contendingTeams(int n) => n == 1
      ? 'Another team is also working on this zone — first to solve it wins.'
      : '$n other teams are also working on this zone — first to solve it wins.';
  static const previouslyTried = 'Already tried by your team:';

  // Region context — the place the pole sits in, plus how to reach it
  // and what to expect, gathered up the region hierarchy.
  static const regionHeading = 'Where this is';
  static const regionEntryLabel = 'Getting in';
  static const regionAccessibilityLabel = 'Accessibility';

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

  // Capture-celebration stamp (slams over the screen on a correct
  // answer; deliberately terse, like a bureaucratic seal).
  static const capturedStamp = 'CLAIMED';

  // Outcome text
  static const correctAndLocked =
      'Correct! Zone captured and now fully locked.';
  static const correctPoleCaptured = 'Correct! Zone captured.';
  static String incorrect(int remaining) =>
      'Incorrect. $remaining attempt(s) left.';
  static const lockedOut = 'Locked out — too many wrong answers.';
  static const alreadyCapturedByOther =
      'Another team captured this relic first.';
  static const alreadyOwner =
      'Your team already owns this zone. Wait for a rival.';

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

  // Native buttons for the JavaScript dialogs the /details page raises
  // (e.g. the "delete your account" confirmation). webview_flutter
  // shows no dialog for window.confirm/alert unless we handle it, so
  // these back the handlers registered in the route.
  static const dialogOk = 'OK';
  static const dialogCancel = 'Cancel';

  // Shown after the account is deleted from the /details page and the
  // app logs itself out.
  static const accountDeleted = 'Your account has been deleted.';
}

// Credits copy lives in routes/credits_route.dart, not here — it's
// real-world chrome (thanks, music, libraries), never in-storyline,
// so it doesn't need the voice-tweaking treatment the rest of this
// file gets.
