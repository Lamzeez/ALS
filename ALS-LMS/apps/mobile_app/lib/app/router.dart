import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/pending_approval_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/student/dashboard/screens/dashboard_screen.dart';
import '../features/teacher/screens/teacher_dashboard_screen.dart';
import '../features/splash/screens/splash_screen.dart';
import '../features/student/enrollment/screens/enroll_course_screen.dart';

/// A class that converts a Stream into a Listenable for GoRouter.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class AlsRouter {
  static GoRouter createRouter(AuthBloc authBloc) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      redirect: (context, state) {
        final authState = authBloc.state;
        
        final bool isLoggingIn = state.matchedLocation == '/login';
        final bool isRegistering = state.matchedLocation == '/register';
        final bool isSplashing = state.matchedLocation == '/';

        // 1. Handle Unauthenticated users
        if (authState is AuthUnauthenticated) {
          if (isLoggingIn || isRegistering) return null;
          return '/login';
        }

        // 2. Handle Loading / Splash
        if (authState is AuthLoading && isSplashing) {
          return '/';
        }

        // 3. Handle Onboarding (Google Sign-In needs role selection)
        if (authState is AuthNeedsOnboarding) {
          if (state.matchedLocation == '/onboarding') return null;
          return '/onboarding';
        }

        // 4. Handle Pending Approval (Teachers)
        if (authState is AuthPendingApproval) {
          if (state.matchedLocation == '/pending-approval') return null;
          return '/pending-approval';
        }

        // 5. Handle Authenticated Users
        if (authState is AuthAuthenticated) {
          // If they are on a guest screen but logged in, move them to their dashboard
          if (isLoggingIn || isRegistering || isSplashing || state.matchedLocation == '/onboarding') {
            final role = authState.profile?.role;
            if (role == UserRole.teacher || 
                role == UserRole.systemAdmin || 
                role == UserRole.centerAdmin) {
              return '/teacher-dashboard';
            }
            return '/student-dashboard';
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/pending-approval',
          builder: (context, state) => const PendingApprovalScreen(),
        ),
        
        // --- STUDENT UI BRANCH ---
        GoRoute(
          path: '/student-dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/enroll',
          builder: (context, state) => const EnrollCourseScreen(),
        ),
        
        // --- TEACHER UI BRANCH ---
        GoRoute(
          path: '/teacher-dashboard',
          builder: (context, state) => const TeacherDashboardScreen(),
        ),
      ],
    );
  }
}

