import 'package:flutter/material.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/models/pole.dart';

/// Shown pinned over the map in place of [InProgressCard] once the game has
/// ended — so every player sees the simulation is over where their in-progress
/// puzzlet used to be, rather than a stale "working on" card.
class SimulationEndedCard extends StatelessWidget {
  const SimulationEndedCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            const Icon(Icons.flag_outlined, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                PuzzletStrings.gameOver,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The team's active ("in progress") puzzlet, pinned over the map so
/// any member can resume it without rescanning. Tap to open; the
/// close button gives it up.
class InProgressCard extends StatelessWidget {
  final ScanResult entry;
  final VoidCallback onOpen;
  final VoidCallback onGiveUp;

  const InProgressCard({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.onGiveUp,
  });

  @override
  Widget build(BuildContext context) {
    final name = entry.pole.name;
    final instructions = entry.activePuzzlet?.instructions ?? '';
    return Card(
      elevation: 3,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${GameplayStrings.inProgressHeading}: $name',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (instructions.isNotEmpty)
                      Text(
                        instructions,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (entry.contendingTeams > 0)
                      Text(
                        GameplayStrings.othersHere(entry.contendingTeams),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                  ],
                ),
              ),
              TextButton(
                  onPressed: onOpen, child: const Text(GameplayStrings.resume)),
              IconButton(
                tooltip: GameplayStrings.giveUp,
                icon: const Icon(Icons.close),
                onPressed: onGiveUp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
