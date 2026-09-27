import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/onboarding.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.init();
  runApp(
    ChangeNotifierProvider.value(
      value: state,
      child: const GrandvoiceApp(),
    ),
  );
}

class GrandvoiceApp extends StatelessWidget {
  const GrandvoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grandvoice',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const SplashScreen(),
    );
  }
}
