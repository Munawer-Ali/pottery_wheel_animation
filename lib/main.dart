import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'model/palette.dart';
import 'screens/studio_screen.dart';
import 'store/pot_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  await PotStore.instance.load();
  runApp(const PotteryWheelApp());
}

class PotteryWheelApp extends StatelessWidget {
  const PotteryWheelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wheel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kClay),
        scaffoldBackgroundColor: kBackdropBottom,
      ),
      home: const StudioScreen(),
    );
  }
}
