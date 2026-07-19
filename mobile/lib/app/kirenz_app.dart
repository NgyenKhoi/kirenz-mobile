import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';
import '../features/chat/presentation/controllers/chat_realtime_controller.dart';
import '../features/auth/presentation/controllers/session_controller.dart';
import '../features/notifications/presentation/controllers/notification_controller.dart';
import '../features/notifications/presentation/widgets/foreground_notification_banner.dart';

class KirenzApp extends ConsumerStatefulWidget {
  const KirenzApp({super.key});

  @override
  ConsumerState<KirenzApp> createState() => _KirenzAppState();
}

class _KirenzAppState extends ConsumerState<KirenzApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final realtime = ref.read(chatRealtimeControllerProvider.notifier);
    final authenticated = ref.read(sessionControllerProvider).isAuthenticated;
    final notifications = authenticated
        ? ref.read(notificationControllerProvider.notifier)
        : null;
    if (state == AppLifecycleState.resumed) {
      realtime.onResumed();
      notifications?.onResumed();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      realtime.onBackground();
      notifications?.onBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final authenticated = ref.watch(
      sessionControllerProvider.select((state) => state.isAuthenticated),
    );

    return MaterialApp.router(
      title: 'Kirenz',
      theme: KirenzTheme.light,
      darkTheme: KirenzTheme.dark,
      routerConfig: router,
      builder: (context, child) => ForegroundNotificationLayer(
        router: router,
        enabled: authenticated,
        child: child ?? const SizedBox.shrink(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
