import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'providers/bookmarks_provider.dart';
import 'providers/content_provider.dart';
import 'services/storage_service.dart';
import 'router/app_router.dart';

void main() {
  runZonedGuarded(_boot, (error, stack) {
    debugPrint('Unhandled error: $error');
  });
}

Future<void> _boot() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await StorageService().initialize();
  } catch (e) {
    debugPrint('Storage init failed (continuing without persistence): $e');
  }

  FlutterError.onError = (details) {
    debugPrint('Flutter error: ${details.exceptionAsString()}');
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DataProvider()),
        ChangeNotifierProvider(create: (_) => BookmarksProvider()),
        ChangeNotifierProvider(create: (_) => ContentProvider()),
      ],
      child: const VibeKLAApp(),
    ),
  );
}

class VibeKLAApp extends StatefulWidget {
  const VibeKLAApp({super.key});

  @override
  State<VibeKLAApp> createState() => _VibeKLAAppState();
}

class _VibeKLAAppState extends State<VibeKLAApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().restoreSession().catchError((_) {});
      context.read<ContentProvider>().fetchContent().catchError((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'VibeKLA',
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
