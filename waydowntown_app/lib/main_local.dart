import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'flavors.dart';
import 'main.dart' as runner;

Future<void> main() async {
  await dotenv.load(fileName: '.env.local').then(
    (_) {
      print('Loaded .env.local');
      print(dotenv.env);
    },
    onError: (_) async {
      await dotenv.load(fileName: '.env');
      print('Loaded .env');
      print(dotenv.env);
    },
  );

  F.appFlavor = Flavor.local;
  await runner.main();
}
