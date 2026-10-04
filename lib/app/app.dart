// lib/app/app.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streakin/app/router.dart';
import 'package:streakin/app/theme/app_theme.dart';
import 'package:streakin/features/settings/application/settings_providers.dart';

class StreakinApp extends ConsumerWidget {
  const StreakinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Streakin', // TODO(rename)
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.of(context).textScaler.scale(1).clamp(0.8, 2.0),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
