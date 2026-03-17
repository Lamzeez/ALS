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
    url: 'https://wxqnwilsegbqtmejdkqw.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind4cW53aWxzZWdicXRtZWpka3F3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwNjM0ODksImV4cCI6MjA4ODYzOTQ4OX0.YF7Sms7XMI2bJmJmjIjTej24T88KaMVif4Tm5OlHFks',
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
