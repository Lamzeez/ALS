import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:backend_services/backend_services.dart';

import '../features/auth/bloc/auth_bloc.dart';
import 'router.dart';

/// Root widget of the ALS Student App.
class AlsStudentApp extends StatefulWidget {
  final ConnectivityService connectivityService;

  const AlsStudentApp({
    super.key,
    required this.connectivityService,
  });

  @override
  State<AlsStudentApp> createState() => _AlsStudentAppState();
}

class _AlsStudentAppState extends State<AlsStudentApp> {
  late final AuthBloc _authBloc;

  @override
  void initState() {
    super.initState();
    // Initialize AuthBloc here so we can pass it to the Router
    _authBloc = AuthBloc(
      authService: AuthService(),
      biometricService: BiometricService(),
    )..add(AuthCheckRequested());
  }

  @override
  void dispose() {
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthService>(
          create: (_) => AuthService(),
        ),
        RepositoryProvider<BiometricService>(
          create: (_) => BiometricService(),
        ),
        RepositoryProvider<ConnectivityService>.value(
          value: widget.connectivityService,
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
      child: BlocProvider<AuthBloc>.value(
        value: _authBloc,
        child: MaterialApp.router(
          title: '9Class',
          debugShowCheckedModeBanner: false,
          theme: AlsTheme.lightTheme,
          darkTheme: AlsTheme.darkTheme,
          themeMode: ThemeMode.system,
          routerConfig: AlsRouter.createRouter(_authBloc),
        ),
      ),    );
  }
}

