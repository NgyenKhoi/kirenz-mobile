import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class KirenzApp extends ConsumerWidget {
  const KirenzApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Kirenz',
      theme: KirenzTheme.light,
      darkTheme: KirenzTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
