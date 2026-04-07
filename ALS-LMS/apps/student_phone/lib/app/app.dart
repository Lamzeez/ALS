import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_services/shared_services.dart';
import 'package:shared_ui/shared_ui.dart';

import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/pending_approval_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/teacher/screens/teacher_dashboard_screen.dart';
import '../features/splash/screens/splash_screen.dart';
import '../features/enrollment/screens/enroll_course_screen.dart';

/// Root widget of the ALS Student App.
class AlsStudentApp extends StatelessWidget {
  final ConnectivityService connectivityService;

  const AlsStudentApp({
    super.key,
    required this.connectivityService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthService>(
          create: (_) => AuthService(),
        ),
        RepositoryProvider<ConnectivityService>.value(
          value: connectivityService,
        ),
        RepositoryProvider<CourseService>(
          create: (_) => CourseService(),
        ),
        RepositoryProvider<AnnouncementService>(
          create: (_) => AnnouncementService(),
        ),
        RepositoryProvider<SystemService>(
          create: (_) => SystemService(),
        ),
      ],
      child: BlocProvider(
        create: (context) => AuthBloc(
          authService: context.read<AuthService>(),
        )..add(AuthCheckRequested()),
        child: MaterialApp(
          title: 'ALS Student',
          debugShowCheckedModeBanner: false,
          theme: AlsTheme.lightTheme,
          darkTheme: AlsTheme.darkTheme,
          themeMode: ThemeMode.system,
          routes: {
            '/': (context) => _buildHomeScreen(context),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/dashboard': (context) => const DashboardScreen(),
            '/enroll': (context) => const EnrollCourseScreen(),
          },
          initialRoute: '/',
        ),
      ),
    );
  }

  Widget _buildHomeScreen(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthLoading) {
          return const SplashScreen();
        } else if (state is AuthNeedsOnboarding) {
          // Brand-new Google sign-in — pick role
          return const OnboardingScreen();
        } else if (state is AuthPendingApproval) {
          // Teacher registered but not yet approved
          return const PendingApprovalScreen();
        } else if (state is AuthAuthenticated) {
          final role = state.profile?.role;
          if (role == UserRole.teacher ||
              role == UserRole.schoolAdmin ||
              role == UserRole.devAdmin) {
            return const TeacherDashboardScreen();
          }
          return const DashboardScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
