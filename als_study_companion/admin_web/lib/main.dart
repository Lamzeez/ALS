import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'viewmodels/admin_auth_viewmodel.dart';
import 'viewmodels/user_management_viewmodel.dart';
import 'viewmodels/content_management_viewmodel.dart';
import 'viewmodels/analytics_viewmodel.dart';
import 'viewmodels/center_management_viewmodel.dart';
import 'admin_login_page.dart';
import 'dashboard/admin_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qxknqcoaaeojbdwtqeov.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF4a25xY29hYWVvamJkd3RxZW92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwNjUzMzQsImV4cCI6MjA4ODY0MTMzNH0.6IPneO_0zNV5Z-dzRF58fRU9DbY7lXRri2AkPK-5Ap0',
    debug: false,
  );

  runApp(const AdminWebApp());
}

class AdminWebApp extends StatelessWidget {
  const AdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminAuthViewModel()),
        ChangeNotifierProvider(create: (_) => UserManagementViewModel()),
        ChangeNotifierProvider(create: (_) => ContentManagementViewModel()),
        ChangeNotifierProvider(create: (_) => AnalyticsViewModel()),
        ChangeNotifierProvider(create: (_) => CenterManagementViewModel()),
      ],
      child: MaterialApp(
        title: 'ALS Admin Panel',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0D47A1),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: Consumer<AdminAuthViewModel>(
          builder: (context, auth, child) => auth.isAuthenticated
              ? const AdminShell()
              : const AdminLoginPage(),
        ),
      ),
    );
  }
}
