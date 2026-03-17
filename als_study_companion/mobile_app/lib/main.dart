import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/services/connectivity_service.dart';
import 'core/database/database_helper.dart';
import 'core/local/local_database.dart';
import 'core/services/supabase_auth_service.dart';
import 'core/services/biometric_service.dart';
import 'core/services/secure_credential_storage.dart';
import 'shared/viewmodels/auth_viewmodel.dart';
import 'shared/viewmodels/sync_viewmodel.dart';
import 'student/viewmodels/lesson_viewmodel.dart';
import 'student/viewmodels/quiz_viewmodel.dart';
import 'student/viewmodels/progress_viewmodel.dart';
import 'student/viewmodels/download_viewmodel.dart';
import 'student/viewmodels/progress_export_viewmodel.dart';
import 'teacher/viewmodels/teacher_lesson_viewmodel.dart';
import 'teacher/viewmodels/video_upload_viewmodel.dart';
import 'teacher/viewmodels/quiz_creator_viewmodel.dart';
import 'teacher/viewmodels/student_monitor_viewmodel.dart';
import 'teacher/viewmodels/session_viewmodel.dart';
import 'teacher/viewmodels/announcement_viewmodel.dart';
import 'shared/views/role_selection_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local database
  await DatabaseHelper.instance.database;

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint(
      'Warning: .env file not found. Using default values for development.',
    );
  }

  // Initialize Supabase
  await Supabase.initialize(
    url:
        dotenv.env['SUPABASE_URL'] ??
        'https://wxqnwilsegbqtmejdkqw.supabase.co',
    anonKey:
        dotenv.env['SUPABASE_ANON_KEY'] ??
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind4cW53aWxzZWdicXRtZWpka3F3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwNjM0ODksImV4cCI6MjA4ODYzOTQ4OX0.YF7Sms7XMI2bJmJmjIjTej24T88KaMVif4Tm5OlHFks',
    debug: false,
  );

  runApp(const ALSStudyCompanionApp());
}

class ALSStudyCompanionApp extends StatelessWidget {
  const ALSStudyCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core Services
        Provider<ConnectivityService>(
          create: (_) => ConnectivityService(),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<LocalDatabase>(
          create: (_) => LocalDatabase(),
          dispose: (_, db) => db.close(),
        ),
        Provider<SupabaseAuthService>(create: (_) => SupabaseAuthService()),
        Provider<BiometricService>(create: (_) => BiometricService()),
        Provider<SecureCredentialStorage>(
          create: (_) => SecureCredentialStorage(),
        ),

        // Shared ViewModels
        ChangeNotifierProvider(
          create: (context) => AuthViewModel(
            authService: context.read<SupabaseAuthService>(),
            localDb: context.read<LocalDatabase>(),
            biometricService: context.read<BiometricService>(),
            credentialStorage: context.read<SecureCredentialStorage>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => SyncViewModel()),

        // Student ViewModels
        ChangeNotifierProvider(create: (_) => LessonViewModel()),
        ChangeNotifierProvider(create: (_) => QuizViewModel()),
        ChangeNotifierProvider(create: (_) => ProgressViewModel()),
        ChangeNotifierProvider(create: (_) => DownloadViewModel()),
        ChangeNotifierProvider(create: (_) => ProgressExportViewModel()),

        // Teacher ViewModels
        ChangeNotifierProvider(create: (_) => TeacherLessonViewModel()),
        ChangeNotifierProvider(create: (_) => VideoUploadViewModel()),
        ChangeNotifierProvider(create: (_) => QuizCreatorViewModel()),
        ChangeNotifierProvider(create: (_) => StudentMonitorViewModel()),
        ChangeNotifierProvider(create: (_) => SessionViewModel()),
        ChangeNotifierProvider(create: (_) => AnnouncementViewModel()),
      ],
      child: MaterialApp(
        title: 'ALS Study Companion',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        ),
        home: const RoleSelectionView(),
      ),
    );
  }
}
