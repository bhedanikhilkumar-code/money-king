import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'backend/supabase_backend.dart';
import 'providers/app_state.dart';
import 'screens/root_shell.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBackend.initialize();
  final appState = AppState();
  await appState.initialize();
  runApp(MyMoneyApp(appState: appState));
}

class MyMoneyApp extends StatelessWidget {
  const MyMoneyApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'Money King',
            debugShowCheckedModeBanner: false,
            themeAnimationDuration: const Duration(milliseconds: 360),
            themeAnimationCurve: Curves.easeInOutCubic,
            themeMode: state.themeMode,
            theme: AppTheme.build(Brightness.light, state.accentColor),
            darkTheme: AppTheme.build(Brightness.dark, state.accentColor),
            home: const RootShell(),
          );
        },
      ),
    );
  }
}
