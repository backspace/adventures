import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/models/accessibility.dart';
import 'package:landgrab/models/pole.dart';
import 'package:landgrab/routes/puzzlet_route.dart';
import 'package:landgrab/widgets/landgrab_app_bar.dart';

/// What the scan flow hands back to the map: the scanned barcode
/// (signals a refresh is worthwhile) and, when the flow ended in a
/// successful capture, the captured pole's id so the map can replay
/// the territory animation.
typedef ScanRouteResult = ({String barcode, String? capturedPoleId});

/// The team's answer to an accessibility conflict on the served puzzlet: take
/// it on themselves, move to the next stake's puzzlet, or (on a stake nothing
/// suits) claim the ground without solving.
enum _ConflictChoice { take, skip, claim }

class ScanRoute extends StatefulWidget {
  final LandgrabApi api;
  // Forwarded to the PuzzletRoute this scan opens, so it can pop back to the
  // map if the puzzlet is resolved out from under the solver.
  final Stream<String>? teamPuzzletsChanged;
  final String? teamId;
  // Forwarded to the PuzzletRoute this scan opens, so a relic viewed after
  // the game has ended opens with its answer entry already disabled.
  final DateTime? gameEndsAt;
  const ScanRoute({
    super.key,
    required this.api,
    this.teamPuzzletsChanged,
    this.teamId,
    this.gameEndsAt,
  });

  @override
  State<ScanRoute> createState() => _ScanRouteState();
}

class _ScanRouteState extends State<ScanRoute> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null) return;

    setState(() => _processing = true);
    await _controller.stop();

    // No team → can't claim anything yet. Warn and return to the map
    // rather than hitting the scan endpoint or opening a relic. (Gameplay
    // has begun for them to reach the scanner, but they still need a team.)
    if (widget.teamId == null) {
      await _showNoTeamDialog();
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    try {
      final outcome = await widget.api.scan(barcode);
      if (!mounted) return;

      switch (outcome) {
        case ScanUnknownBarcode():
          await _showUnknownBarcodeDialog(barcode);
          if (!mounted) return;
          setState(() => _processing = false);
          _controller.start();
          return;

        case ScanAlreadyOwner(:final pole):
          await _showAlreadyOwnerDialog(pole);
          if (!mounted) return;
          Navigator.of(context).pop((barcode: barcode, capturedPoleId: null));
          return;

        case ScanTeamLockedOut(:final pole):
          await _showTeamLockedOutDialog(pole);
          if (!mounted) return;
          Navigator.of(context).pop((barcode: barcode, capturedPoleId: null));
          return;

        case ScanOwnCreation(:final pole):
          await _showOwnCreationDialog(pole);
          if (!mounted) return;
          Navigator.of(context).pop((barcode: barcode, capturedPoleId: null));
          return;

        case ScanOutsideZone(:final pole):
          await _showOutsideZoneDialog(pole);
          if (!mounted) return;
          Navigator.of(context).pop((barcode: barcode, capturedPoleId: null));
          return;

        case ScanNotStarted():
          _showSnack(ScanStrings.notStarted);
          Navigator.of(context).pop((barcode: barcode, capturedPoleId: null));
          return;

        case ScanAtCapacity(:final active):
          await _showAtCapacityDialog(active);
          if (!mounted) return;
          Navigator.of(context).pop((barcode: barcode, capturedPoleId: null));
          return;

        case ScanFound(:final result):
          // Resolve any accessibility conflict by asking the team (surface,
          // don't decide), then open the puzzlet they accept. Capture the
          // navigator up front so it's not read off `context` across the
          // awaits in the loop below.
          final navigator = Navigator.of(context);
          var current = result;
          final declined = <String>[];

          while (true) {
            if (current.activePuzzlet == null) {
              // Nothing (left) to serve. On a prohibitive stake that's the
              // dead-end where claiming without solving is offered.
              if (current.pole.prohibitive) {
                if (await _confirmClaim() && mounted) {
                  await _claimWithoutSolving(navigator, barcode, current.pole.id);
                  return;
                }
                if (!mounted) return;
              } else {
                _showSnack(current.pole.locked
                    ? ScanStrings.poleFullyCaptured
                    : ScanStrings.noActivePuzzlet);
              }
              navigator.pop((barcode: barcode, capturedPoleId: null));
              return;
            }

            if (current.hasConflict) {
              // "Claim it" only where the whole stake is prohibitive — a stake
              // with a doable relic must be solved, not claimed.
              final choice = await _showConflictChoice(
                current.conflictTags,
                canClaim: current.pole.prohibitive,
              );
              if (!mounted) return;

              if (choice == _ConflictChoice.claim) {
                if (await _confirmClaim() && mounted) {
                  // Let go of the held (conflicting) puzzlet, then claim.
                  await widget.api
                      .abandonActivePuzzlet(current.activePuzzlet!.id);
                  await _claimWithoutSolving(navigator, barcode, current.pole.id);
                  return;
                }
                if (!mounted) return;
                continue; // confirm dismissed — re-offer the choice
              }

              // Dismissed, or "not this one": let go of the held puzzlet.
              if (choice != _ConflictChoice.take) {
                await widget.api
                    .abandonActivePuzzlet(current.activePuzzlet!.id);
              }
              if (choice == _ConflictChoice.skip) {
                declined.add(current.activePuzzlet!.id);
                final next = await widget.api.scan(barcode, exclude: declined);
                if (!mounted) return;
                if (next is ScanFound) {
                  current = next.result;
                  continue; // evaluate the next-served puzzlet
                }
                // State shifted under us (e.g. a rival captured) — back to map.
                navigator.pop((barcode: barcode, capturedPoleId: null));
                return;
              }
              if (choice == null) {
                // Cancelled — nothing committed; return to the map.
                navigator.pop((barcode: barcode, capturedPoleId: null));
                return;
              }
            }
            break; // no conflict, or "we've got it" — open it
          }

          // PuzzletRoute pops `true` after a successful capture (and
          // its celebration). Relay the captured pole's id to the map so
          // it can replay the territory animation on arrival — the
          // socket broadcast usually fires while the player is still
          // on the puzzlet screen, so without this they'd miss it.
          final captured = await navigator.push<bool>(
            MaterialPageRoute(
              builder: (_) => PuzzletRoute(
                api: widget.api,
                pole: current.pole,
                puzzlet: current.activePuzzlet!,
                contendingTeams: current.contendingTeams,
                teamPuzzletsChanged: widget.teamPuzzletsChanged,
                teamId: widget.teamId,
                gameEndsAt: widget.gameEndsAt,
              ),
            ),
          );

          if (!mounted) return;
          Navigator.of(context).pop((
            barcode: barcode,
            capturedPoleId: captured == true ? current.pole.id : null,
          ));
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(ScanStrings.scanFailed(e.toString()));
      setState(() => _processing = false);
      _controller.start();
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showNoTeamDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(ScanStrings.noTeamTitle),
        content: const Text(ScanStrings.noTeamBody),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(ScanStrings.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _showUnknownBarcodeDialog(String barcode) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(ScanStrings.unknownBarcodeTitle),
        content: Text(ScanStrings.unknownBarcodeBody(barcode)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: const Text(ScanStrings.unknownBarcodeBack),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(ScanStrings.unknownBarcodeRetry),
          ),
        ],
      ),
    );
  }

  Future<void> _showAlreadyOwnerDialog(Pole pole) {
    final name = pole.name;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(ScanStrings.alreadyOwnerTitle),
        content: Text(ScanStrings.alreadyOwnerBody(name)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(ScanStrings.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _showOwnCreationDialog(Pole pole) {
    final name = pole.name;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(ScanStrings.ownCreationTitle),
        content: Text(ScanStrings.ownCreationBody(name)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(ScanStrings.ok),
          ),
        ],
      ),
    );
  }

  /// The served relic has accessibility requirements a member of the cohort
  /// set aside. Ask, rather than deciding: take it on (split up, whoever can),
  /// or move to the next. Names the specific requirement(s) so the team can
  /// judge. When [canClaim] (the whole stake is prohibitive), also offers
  /// claiming without solving. Dismissing (returns null) cancels to the map.
  Future<_ConflictChoice?> _showConflictChoice(List<String> conflictTags,
      {required bool canClaim}) {
    final requirements = conflictTags.map(accessibilityTagLabel).join(', ');
    return showDialog<_ConflictChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(ScanStrings.conflictTitle),
        content: Text(ScanStrings.conflictBody(requirements, canClaim: canClaim)),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ConflictChoice.skip),
            child: const Text(ScanStrings.conflictSkip),
          ),
          if (canClaim)
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_ConflictChoice.claim),
              child: const Text(ScanStrings.conflictClaim),
            ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ConflictChoice.take),
            child: const Text(ScanStrings.conflictTake),
          ),
        ],
      ),
    );
  }

  /// Confirm before claiming a stake without solving — it takes the ground
  /// from another team, so it's a deliberate step, not a stray tap.
  Future<bool> _confirmClaim() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(ScanStrings.claimConfirmTitle),
        content: const Text(ScanStrings.claimConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(ScanStrings.claimCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(ScanStrings.claimConfirm),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /// Record the accommodation claim and return to the map. Passes the pole id
  /// so the map replays the ownership animation on arrival.
  Future<void> _claimWithoutSolving(
      NavigatorState navigator, String barcode, String poleId) async {
    try {
      await widget.api.claimWithoutSolving(barcode);
      if (!mounted) return;
      navigator.pop((barcode: barcode, capturedPoleId: poleId));
    } catch (e) {
      if (!mounted) return;
      _showSnack(ScanStrings.claimFailed);
      navigator.pop((barcode: barcode, capturedPoleId: null));
    }
  }

  Future<void> _showAtCapacityDialog(List<ScanResult> active) {
    final current = active.isEmpty
        ? 'another puzzlet'
        : active.first.pole.name;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(GameplayStrings.atCapacityTitle),
        content: Text(GameplayStrings.atCapacityBody(current)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(ScanStrings.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _showOutsideZoneDialog(Pole pole) {
    final name = pole.name;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(ScanStrings.outsideZoneTitle),
        content: Text(ScanStrings.outsideZoneBody(name)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(ScanStrings.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _showTeamLockedOutDialog(Pole pole) {
    final name = pole.name;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(ScanStrings.lockedOutTitle),
        content: Text(ScanStrings.lockedOutBody(name)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(ScanStrings.ok),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LandgrabAppBar(title: ScanStrings.appBarTitle),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          if (_processing)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
