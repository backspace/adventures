import 'package:flutter/material.dart';
import 'package:waydowntown/models/region.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/models/specification.dart';

class RunHeader extends StatelessWidget {
  final Run run;

  const RunHeader({super.key, required this.run});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          getRegionPath(run.specification),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (run.description != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(run.description!),
          ),
        if (run.startedAt != null && run.specification.duration != null)
          CountdownTimer(game: run),
      ],
    );
  }
}

String getRegionPath(Specification specification) {
  List<String> regionNames = [];
  Region? currentRegion = specification.region;

  while (currentRegion != null) {
    regionNames.insert(0, currentRegion.name);
    currentRegion = currentRegion.parentRegion;
  }

  return regionNames.join(" > ");
}

class CountdownTimer extends StatefulWidget {
  final Run game;

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
        Duration(seconds: widget.game.specification.duration!),
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
