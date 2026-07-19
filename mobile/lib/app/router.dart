import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/controllers/session_controller.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/otp_verification_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/chat/presentation/screens/chat_screen.dart';
import '../features/chat/presentation/screens/conversation_screen.dart';
import '../features/chat/presentation/screens/group_settings_screen.dart';
import '../features/blocks/presentation/screens/blocked_users_screen.dart';
import '../features/explore/presentation/screens/explore_screen.dart';
import '../features/feed/presentation/screens/feed_screen.dart';
import '../features/friends/presentation/screens/friends_screen.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';
import '../features/privacy/presentation/screens/privacy_screen.dart';
import '../features/profile/presentation/screens/edit_profile_screen.dart';
import '../features/profile/presentation/screens/edit_cover_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/posts/presentation/screens/post_detail_screen.dart';
import '../shared/widgets/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionControllerProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final location = state.uri.path;
      final isAuthRoute =
          location == '/login' ||
          location == '/register' ||
          location == '/verify-otp';
      final isSplash = location == '/splash';
      final isUnsupportedRole = location == '/unsupported-account';

      if (session.status == SessionStatus.checking) {
        return isSplash ? null : '/splash';
      }

      if (session.status == SessionStatus.unsupportedRole) {
        return isUnsupportedRole ? null : '/unsupported-account';
      }

      if (!session.isAuthenticated) {
        if (isAuthRoute) return null;
        final intended = Uri.encodeComponent(state.uri.toString());
        return '/login?redirect=$intended';
      }

      if (isAuthRoute || isSplash) {
        final intended = state.uri.queryParameters['redirect'];
        if (intended != null &&
            intended.startsWith('/') &&
            !intended.startsWith('/login') &&
            !intended.startsWith('/register') &&
            !intended.startsWith('/verify-otp')) {
          return intended;
        }
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) => OtpVerificationScreen(
          email: state.uri.queryParameters['email'],
          otpWasSent: state.uri.queryParameters['otpSent'] == 'true',
          intendedDestination: state.uri.queryParameters['redirect'],
        ),
      ),
      GoRoute(
        path: '/unsupported-account',
        builder: (context, state) => const _UnsupportedAccountScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const FeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                builder: (context, state) => ExploreScreen(
                  initialQuery: state.uri.queryParameters['query'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/friends',
                builder: (context, state) => FriendsScreen(
                  initialSegment: state.uri.queryParameters['segment'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatScreen(),
                routes: [
                  GoRoute(
                    path: ':conversationId',
                    builder: (context, state) => ConversationScreen(
                      conversationId:
                          state.pathParameters['conversationId'] ?? '',
                    ),
                  ),
                  GoRoute(
                    path: ':conversationId/settings',
                    builder: (context, state) => GroupSettingsScreen(
                      conversationId:
                          state.pathParameters['conversationId'] ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile/me',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/profile/edit',
        pageBuilder: (context, state) =>
            const MaterialPage(child: EditProfileScreen()),
      ),
      GoRoute(
        path: '/profile/me/cover',
        pageBuilder: (context, state) =>
            const MaterialPage(child: EditCoverScreen()),
      ),
      GoRoute(
        path: '/profile/:userId',
        pageBuilder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          return MaterialPage(child: ProfileScreen(userId: userId));
        },
      ),
      GoRoute(
        path: '/privacy',
        pageBuilder: (context, state) =>
            const MaterialPage(child: PrivacyScreen()),
      ),
      GoRoute(
        path: '/blocked-users',
        pageBuilder: (context, state) =>
            const MaterialPage(child: BlockedUsersScreen()),
      ),
      GoRoute(
        path: '/post/:postId',
        pageBuilder: (context, state) => MaterialPage(
          child: PostDetailScreen(postId: state.pathParameters['postId'] ?? ''),
        ),
      ),
    ],
  );
});

class _UnsupportedAccountScreen extends ConsumerWidget {
  const _UnsupportedAccountScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kirenz Mobile')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings_outlined, size: 56),
                const SizedBox(height: 16),
                Text(
                  'This account is managed in the Kirenz admin portal.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'The mobile app currently supports user accounts only.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: session.pendingAction == AuthPendingAction.logout
                      ? null
                      : () => ref
                            .read(sessionControllerProvider.notifier)
                            .signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
