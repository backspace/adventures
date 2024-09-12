import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'flavors.dart';
import 'main.dart' as runner;

Future<void> main() async {
  await dotenv.load(fileName: '.env');

  F.appFlavor = Flavor.production;
  await runner.main();
}
