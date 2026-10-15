import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'storage/project_repository.dart';
import 'ui/project_list_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = ProjectStore(ProjectRepository());
  runApp(GartenPlanApp(store: store));
}

class GartenPlanApp extends StatelessWidget {
  const GartenPlanApp({super.key, required this.store});

  final ProjectStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GartenPlan',
      debugShowCheckedModeBanner: false,
      theme: buildGartenTheme(),
      locale: const Locale('de'),
      supportedLocales: const [Locale('de')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ProjectListScreen(store: store),
    );
  }
}
