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

/// In-game vocabulary. Change a term here to rename it everywhere it
/// appears in player-facing copy.
///
///   * [stake] — a pole and the barcode on it (the thing you scan).
///   * [zone]  — the captured area around a stake.
///   * [relic] — the puzzlet (the challenge you solve at a stake).
class Terms {
  Terms._();

  static const stake = 'stake';
  static const stakes = 'stakes';
  static const stakeCap = 'Stake';
  static const zone = 'zone';
  static const zones = 'zones';
  static const zoneCap = 'Zone';
  static const relic = 'relic';
  static const relics = 'relics';
}

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
      'Can’t reach the server. Check your connection (and VPN, if you '
      'use one) and try again.';
  static const loginFailed = 'Sign-in failed. Please try again.';
  static const appleNoIdentityToken =
      'Apple sign-in returned no identity token';

  // Shown when Apple signs a NEW user in without sharing an email (it only
  // sends one on the first authorization). We collect one to finish creating
  // the account.
  static const appleEmailTitle = 'One more thing';
  static const appleEmailBody =
      'Apple didn’t share your email, so we need it to set up your account.';
  static const appleEmailContinue = 'Continue';
  static const appleEmailCancel = 'Cancel';
  static const appleSignInFailed = 'Apple sign-in failed';
  static String appleSignInFailedWith(String detail) =>
      'Apple sign-in failed: $detail';
  static String oauthCancelled(String provider) =>
      '$provider sign-in failed or was cancelled';

  static const noAccountPrompt = 'New here?';
  static const createAccountLink = 'Create an account';
  static const forgotPassword = 'Forgot password?';
}

/// Join-a-team screen (`routes/join_team_route.dart`).
class JoinTeamStrings {
  JoinTeamStrings._();

  static const appBarTitle = 'Join a team';
  static const noTeamPrompt = 'You haven’t joined a team yet.';
  static const intro =
      'Scan your team’s QR code, or type the join code from your team card.';
  static const scanButton = 'Scan team QR';
  static const orDivider = 'or';
  static const codeLabel = 'Join code';
  static const joinButton = 'Join';
  static const success = 'You’ve joined your team.';
  static const notFound =
      'No team found for that code. Double-check it and try again.';
  static const failed = 'Couldn’t join that team. Please try again.';
}

/// Password-reset WebView (`routes/forgot_password_route.dart`), which
/// hosts the registrations site's public `/reset-password/new` page.
class ForgotPasswordStrings {
  ForgotPasswordStrings._();

  static const appBarTitle = 'Reset password';
  static const intro =
      'Enter your email and we’ll send you a link to choose a new '
      'password.';
  static const emailLabel = 'Email';
  static const emailRequired = 'Enter your email address.';
  static const submitButton = 'Send reset link';
  static const sent =
      'If an account exists for that email, a reset link is on its way. '
      'Open it on this device to choose a new password.';
  static const backToSignIn = 'Back to sign in';
  static const serverUnreachable =
      'Can’t reach the server. Check your connection (and VPN, if you '
      'use one) and try again.';
}

/// Sign-up screen (`routes/register_route.dart`), for people arriving
/// without having registered ahead of time.
class RegisterStrings {
  RegisterStrings._();

  static const appBarTitle = 'Create account';
  static const intro =
      'Create an account with your email, then we’ll get your details.';
  static const emailLabel = 'Email';
  static const passwordLabel = 'Password';
  static const createAccountButton = 'Create account';
  static const haveAccountPrompt = 'Already have an account?';
  static const signInLink = 'Sign in';

  static const serverUnreachable =
      'Can’t reach the server. Check your connection (and VPN, if you '
      'use one) and try again.';
  static const failed = 'Couldn’t create your account. Please try again.';
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
  static String lastScanWithType(String value, String type) =>
      'Last: $value · $type';
}

/// Gameplay home body — the map view (`routes/home_route.dart`).
class GameplayStrings {
  GameplayStrings._();

  static const scanFab = 'Scan';
  static const locateMe = 'Locate me';
  static const settings = 'Settings';
  static const credits = 'Credits';
  static const instructions = 'Instructions';
  static const details = 'Your details';

  // Soft "newer build available" banner. The server auto-tracks the newest
  // build it has seen per platform; when this client is behind, nudge (never
  // block) an update.
  static const updateAvailable =
      'A newer version is available — please update to the latest build.';
  static const updateDismiss = 'Dismiss';
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
  static const giveUpTitle = 'Give up on this ${Terms.relic}?';
  static String giveUpBody(String poleName) =>
      'Your team will stop working on $poleName and can pick up a '
      'different ${Terms.stake}. You can come back to this one later.';
  static const giveUpCancel = 'Keep working';
  static const giveUpConfirm = 'Give up';

  // Scan refused because the team already holds a puzzlet.
  static const atCapacityTitle = 'Already on a ${Terms.relic}';
  static String atCapacityBody(String current) =>
      'Your team is already working on $current. Finish it or give it '
      'up before starting another.';

  // A rival captured the puzzlet your team was working on.
  static const puzzletTakenTryNext = 'Try the next one';

  // "View on map" action on an attack / pole-lost toast, and the notice
  // shown when the stake is no longer on the map (e.g. the endgame boundary
  // has passed it, or poles haven't loaded yet).
  static const viewOnMap = 'View';
  static const zoneNotOnMap =
      'That ${Terms.stake} isn’t on your map right now.';

  // How many other teams are also on this pole (shown on the
  // in-progress card).
  static String othersHere(int n) => '$n other${n == 1 ? '' : 's'} here';
  static String couldNotLoadPoles(String error) =>
      'Could not load ${Terms.stakes}: $error';

  // Home-route load failure. A 401 (expired/rejected session) gets its own
  // wording since the fix is usually "try again" then "log out"; anything
  // else is a generic load failure. The raw error hides behind "Details".
  static const loadSessionExpired =
      'Your session needs refreshing. Try again — or log out and back in if '
      'that doesn’t work.';
  static const loadFailed =
      'Something went wrong loading the map. Try again, or log out and back '
      'in if it persists.';
  static const loadTryAgain = 'Try again';
  static const loadShowDetails = 'Show details';
  static const loadHideDetails = 'Hide details';
  static const loadCopyDetails = 'Copy';
  static const loadDetailsCopied = 'Error details copied.';

  // Accessibility: a stake whose every remaining ${Terms.relic} demands
  // something a member of your cohort has set aside. In-fiction, never
  // clinical — matter-of-fact, not othering. Shown on tap. Consistent with the
  // scan choice: a member who's able can still attempt, or the team can claim
  // the stake without solving.
  static const zoneProhibitive =
      'Every ${Terms.relic} here has accessibility requirements a member of your team '
      'has set aside. Scan it to attempt anyway, or claim it without solving.';
  static String prohibitiveHide(int n) =>
      'Hide $n incompatible ${n == 1 ? Terms.stake : Terms.stakes}';
  static String prohibitiveShow(int n) =>
      'Show $n incompatible ${n == 1 ? Terms.stake : Terms.stakes}';

  // Extra lines appended to the tap snackbar so each map icon is explained.
  // A locked stake (lock glyph) — fully captured, nothing left to solve.
  static const zoneLocked =
      'Fully captured — no ${Terms.relics} left to solve here.';
  // A stake under attack (pulsing ring) — a rival recently scanned it.
  static const zoneUnderAttack =
      'Under attack — a rival recently scanned this ${Terms.stake}.';
  // Heading over the accessibility tags/notes in the tap-a-stake sheet, shown
  // for stakes the map badges with the info glyph.
  static const zoneAccessibilityTitle = 'Accessibility';

  // Tap-a-zone owner sheet.
  static const zoneUnclaimed = 'Unclaimed';
  // A liberated zone — freed, belongs to no one (distinct from never-claimed).
  // DRAFT copy, pending the sensitivity pass.
  static const zoneLiberated = 'Liberated — it belongs to no one now.';
  static String zoneOwnerYou(String? team) =>
      team == null ? 'Held by your team' : 'Held by your team ($team)';
  static String zoneOwnerOther(String? team) =>
      'Held by ${team ?? 'another team'}';
}

/// Location-permission pre-prompt rationale, shown just before the OS
/// dialog (`widgets/location_rationale.dart`). The OS dialog's own text is
/// native (iOS: Info.plist `NSLocationWhenInUseUsageDescription`; Android's
/// system dialog text isn't customisable) — this is the in-app explanation
/// shown first so the system ask isn't a cold prompt.
class LocationStrings {
  LocationStrings._();

  static const rationaleTitle = 'Find nearby ${Terms.stakes}';
  static const rationaleBody =
      'Landgrab uses your location to show which ${Terms.stakes} are near you on the '
      'map and to place your position on it. This stays on-device and is only '
      'used by the app to show your location. You can still participate in the '
      'simulation without this if you’re comfortable orienting yourself.';
  static const rationaleContinue = 'Continue';
  static const rationaleNotNow = 'Not now';

  /// Snackbar action shown when location is permanently denied — jumps to
  /// the OS settings page so the user can re-enable it.
  static const openSettings = 'Open Settings';
}

/// Settings screen (`routes/settings_route.dart`) — the player-facing part.
/// The environment switcher below the appearance control stays plain English
/// (it's the dev affordance behind the 7-tap unlock).
class SettingsStrings {
  SettingsStrings._();

  static const appearance = 'Appearance';
  static const themeSystem = 'System';
  static const themeLight = 'Light';
  static const themeDark = 'Dark';

  // Team join QR — a member shows this so someone can join their team by
  // scanning it (the same code the team card carries).
  static const teamQrHeading = 'Invite to your team';
  static const teamQrBody =
      'Have someone scan this with “Join a team” to join you.';
  static String teamQrName(String team) => 'Team $team';
  static const teamQrCodeLabel = 'Join code';
}

/// Instructions screen (`routes/instructions_route.dart`). Like Credits, the
/// body is a local-only bundled file — gitignored, so the storyline briefing
/// isn't published — held back behind [placeholder] until the simulation
/// begins. [unavailable] shows if the file is absent post-start (a build that
/// never had one dropped in).
class InstructionsStrings {
  InstructionsStrings._();

  static const appBarTitle = 'Instructions';
  static const placeholder =
      'Check back here for instructions once the simulation has begun.';
  static const unavailable = 'No instructions were provided for this session.';
}

/// Notification history (`routes/notifications_route.dart`).
class NotificationStrings {
  NotificationStrings._();

  static const title = 'Notifications';
  static const empty =
      'Nothing yet. When a rival team scans your ${Terms.stake} or captures one of your '
      '${Terms.zones}, it shows up here.';
  static String couldNotLoad(String error) =>
      'Could not load notifications: $error';

  // "View on map" button on notifications that point at a stake.
  static const viewOnMap = 'View on map';

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

  // Liberation invite (interactive; DRAFT copy — the invite body itself
  // comes from the server, these are the answer affordances). The first
  // answer binds the whole team.
  static const inviteAccept = 'Join';
  static const inviteDecline = 'Decline';
  static const inviteAccepted = 'Your team joined the subversion.';
  static const inviteDeclined = 'Your team declined.';
  static const inviteAlreadyAnswered = 'Your team had already answered.';
  static const inviteFailed = 'Could not send your answer — try again.';
  // Live-toast action that opens the history, where the answer buttons are.
  static const inviteRespondAction = 'Respond';

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

  static const appBarTitle = 'Scan a ${Terms.stake} barcode';

  // Shown when someone scans before joining a team — they can't claim
  // anything yet, so we warn instead of opening the ${Terms.relic}.
  static const noTeamTitle = 'Join a team first';
  static const noTeamBody =
      'You need a team before you can claim ${Terms.stakes}. Join a team, '
      'then scan again.';

  // Outcome snackbars
  static const poleFullyCaptured = 'This ${Terms.zone} is fully captured.';
  static const poleFullyCapturedTitle = 'Fully captured';
  static const noActivePuzzlet =
      'No active ${Terms.relics} for this ${Terms.stake}.';
  static const notStarted =
      'The simulation hasn’t begun yet — you can’t claim ${Terms.stakes} until it starts.';
  static String scanFailed(String detail) => 'Scan failed: $detail';

  // Accessibility conflict choice: the served ${Terms.relic} has requirements a
  // member of the cohort set aside. Names the specific requirement(s) so the
  // team can decide (split up, or move on) — matter-of-fact, never othering.
  static const conflictTitle = 'Accessibility requirements';
  // The third-option verb flips with stance: a liberator frees the stake
  // rather than claiming it. DRAFT liberate copy, pending the sensitivity pass.
  static String conflictBody(String requirements,
      {bool canClaim = false, bool liberating = false}) {
    final third = !canClaim
        ? ''
        : liberating
            ? ', or liberate this ${Terms.stake} without solving'
            : ', or claim this ${Terms.stake} without solving';
    return 'This ${Terms.relic} has accessibility requirements a member of your '
        'cohort has set aside: $requirements. '
        'Attempt it together, try a different ${Terms.relic} here$third?';
  }

  static const conflictTake = 'We’ll try it';
  static const conflictSkip = 'Give me another';

  // Accommodation: offered on a stake where every relic is incompatible for
  // the cohort — a third option in the conflict dialog and at the
  // decline-everything dead-end. A capturer takes the ground without solving;
  // a liberator frees it without solving.
  static const conflictClaim = 'Claim it';
  static const conflictLiberate = 'Liberate it';
  static const claimConfirmTitle = 'Claim without solving?';
  static const claimConfirmBody =
      'No ${Terms.relic} here suits your cohort. You can claim this '
      '${Terms.stake} for your team without solving. It stays open for teams '
      'who can solve it, so a rival may take it back.';
  static const claimConfirm = 'Claim it';
  // Liberator variants of the confirm dialog.
  static const liberateConfirmTitle = 'Liberate without solving?';
  static const liberateConfirmBody =
      'No ${Terms.relic} here suits your cohort. You can liberate this '
      '${Terms.stake} without solving — it returns to no one.';
  static const liberateConfirm = 'Liberate it';
  static const claimCancel = 'Not now';
  static const claimFailed = 'Couldn’t claim that ${Terms.stake}. Try again.';
  static const liberateFailed =
      'Couldn’t liberate that ${Terms.stake}. Try again.';

  // Unknown-barcode dialog
  static const unknownBarcodeTitle = 'Unknown barcode';
  static String unknownBarcodeBody(String barcode) =>
      '“$barcode” doesn’t match any known ${Terms.stake}. Maybe the correct stake is nearby? Check the map again.';
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
      'Your team has used all attempts on the current ${Terms.relic} for $poleName. '
      'Wait for another team to capture it before you can try again.';

  // Own-creation dialog (authors can't capture their own content)
  static const ownCreationTitle = 'That one’s yours';
  static String ownCreationBody(String poleName) =>
      'You authored $poleName, so you can’t capture it. Leave it for the other teams.';

  // Outside-the-endgame-boundary dialog. The boundary itself is
  // deliberately invisible — poles it has passed vanish from the
  // map — so the copy points at remaining poles, not at a circle.
  static const outsideZoneTitle = 'Out of range';
  static String outsideZoneBody(String poleName) =>
      'The simulation has withdrawn $poleName — it can no longer be '
      'claimed. Only ${Terms.stakes} still on your map remain in play.';

  // Nothing-to-liberate dialog (strict roles: a team that joined the
  // liberation can only free OWNED ground). DRAFT copy.
  static const nothingToLiberateTitle = 'Nothing to liberate';
  static String nothingToLiberateBody(String poleName) =>
      'No one holds $poleName — there is nothing here to free. '
      'Liberate the ${Terms.zones} that are held.';

  // Generic acknowledge button used across the dialogs above.
  static const ok = 'OK';
}

/// Puzzlet-solving route (`routes/puzzlet_route.dart`).
class PuzzletStrings {
  PuzzletStrings._();

  static const titlePrefix = Terms.stakeCap;
  // Small header above the puzzlet instructions, framing what the player is
  // doing at the stake.
  static const findRelicHeader = 'Find this ${Terms.relic}';
  static String attemptsRemaining(int n) => 'Attempts remaining: $n';
  static String contendingTeams(int n) => n == 1
      ? 'Another team is also working on this ${Terms.stake} — first to find the ${Terms.relic} claims the zone.'
      : '$n other teams are also working on this ${Terms.stake} — first to find the ${Terms.relic} claims the zone.';
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

  // Liberation celebration stamp — a correct answer by a team that
  // joined Bedab frees the ground instead of claiming it.
  static const liberatedStamp = 'UNCLAIMED';

  // Outcome text
  static const correctAndLocked =
      'Correct! ${Terms.zoneCap} captured and now fully locked.';
  static const correctPoleCaptured = 'Correct! ${Terms.zoneCap} captured.';
  static String incorrect(int remaining) =>
      'Incorrect. $remaining attempt(s) left.';
  static const lockedOut =
      'Out of guesses — too many wrong answers. Wait for another team to '
      'capture this ${Terms.relic} before you can try again.';
  static const alreadyCapturedByOther =
      'Another team found this ${Terms.relic} first.';
  // The liberator's race: the stake was freed while they were solving.
  static const alreadyLiberated =
      'This ${Terms.zone} was returned to no one while you worked — '
      'it is already free.';
  static const alreadyOwner =
      'Your team already owns this ${Terms.zone}. Wait for a rival to capture it.';
  static const notActive =
      'Scan this ${Terms.stake} to begin before answering.';
  static const withdrawn =
      'This ${Terms.relic} has been withdrawn from the simulation.';
  static const gameOver =
      'The simulation has ended — ${Terms.relics} can no longer be claimed.';
  // Shown when the puzzlet is resolved out from under you (withdrawn, or a
  // rival captured it) while you're on its screen and we return to the map.
  static const noLongerAvailable =
      'This ${Terms.relic} is no longer available.';
  static const ownCreation = "You made this one — you can’t capture it.";

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
