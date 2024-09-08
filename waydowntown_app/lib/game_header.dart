import 'package:flutter/material.dart';
import 'package:waydowntown/models/game.dart';
import 'package:waydowntown/models/incarnation.dart';
import 'package:waydowntown/models/region.dart';

class GameHeader extends StatelessWidget {
  final Game game;

  const GameHeader({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          getRegionPath(game.incarnation),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (game.description != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(game.description!),
          ),
        if (game.startedAt != null && game.incarnation.durationSeconds != null)
          CountdownTimer(game: game),
      ],
    );
  }
}

String getRegionPath(Incarnation incarnation) {
  List<String> regionNames = [];
  Region? currentRegion = incarnation.region;

  while (currentRegion != null) {
    regionNames.insert(0, currentRegion.name);
    currentRegion = currentRegion.parentRegion;
  }

  return regionNames.join(" > ");
}

class CountdownTimer extends StatefulWidget {
  final Game game;

  const CountdownTimer({super.key, required this.game});

  @override
  _CountdownTimerState createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late Stream<int> _timerStream;

  @override
  void initState() {
    super.initState();
    _timerStream = Stream.periodic(const Duration(seconds: 1), (i) {
      final endTime = widget.game.startedAt!.add(
        Duration(seconds: widget.game.incarnation.durationSeconds!),
      );
      return endTime.difference(DateTime.now()).inSeconds;
    }).takeWhile((seconds) => seconds >= 0);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _timerStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          if (snapshot.data! > 0) {
            final minutes = snapshot.data! ~/ 60;
            final seconds = snapshot.data! % 60;
            return Text(
              'Time remaining: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.titleMedium,
            );
          } else {
            return Text(
              'Out of time!',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.red),
            );
          }
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }
}
