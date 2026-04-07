import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_services/shared_services.dart';

import 'app/app.dart';
import 'app/bloc_observer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode for phone
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Supabase — wrapped in try/catch so the app can boot offline
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('[ALS] Supabase init failed: $e — Launching in offline mode.');
  }

  // Initialize connectivity monitoring
  final connectivityService = ConnectivityService();
  await connectivityService.initialize();

  // Set up BLoC observer for debugging
  Bloc.observer = AlsBlocObserver();

  // Set system UI overlay AFTER Flutter engine is ready
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFF8F9FA),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    AlsStudentApp(connectivityService: connectivityService),
  );
}
