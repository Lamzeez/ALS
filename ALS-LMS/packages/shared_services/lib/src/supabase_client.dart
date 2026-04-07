import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String _url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pgfhypaqpzypjofbyugi.supabase.co',
  );
  static const String _anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBnZmh5cGFxcHp5cGpvZmJ5dWdpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0NjQ0MDUsImV4cCI6MjA5MDA0MDQwNX0.UGjgQHXoi5GGiwYBlSuUIfMUylfTJLFgScco5w4JCUA',
  );

  static Future<void> initialize() async {
    await Supabase.initialize(url: _url, anonKey: _anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
