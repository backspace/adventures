import 'package:flutter/material.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/util/get_region_path.dart';
import 'package:waydowntown/widgets/countdown_timer.dart';

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
        if (run.taskDescription != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(run.taskDescription!),
          ),
        if (run.startedAt != null && run.specification.duration != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Time left: '),
              CountdownTimer(game: run),
            ],
          ),
        if (run.totalAnswers > 1)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                CircularProgressIndicator(
                  value: run.correctSubmissions / run.totalAnswers,
                  backgroundColor: Colors.blue.shade200,
                ),
                const SizedBox(width: 10),
                Text('${run.correctSubmissions}/${run.totalAnswers}'),
              ],
            ),
          ),
      ],
    );
  }
}
