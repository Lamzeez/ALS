import 'dart:async';
import 'dart:developer' as developer;
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

  // 🚀 API Configuration
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _longTimeout = Duration(minutes: 2); // For uploads
  static const int _maxRetries = 3;

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: _url,
        anonKey: _anonKey,
        debug: false, // Set to true only in development
      );
      developer.log('Supabase initialized successfully',
          name: 'SupabaseConfig');
    } catch (e, stackTrace) {
      developer.log('Supabase initialization failed',
          error: e,
          stackTrace: stackTrace,
          name: 'SupabaseConfig',
          level: 1000);
      rethrow;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;

  /// 🔄 Execute API call with timeout and retry logic
  static Future<T> withRetry<T>(
    Future<T> Function() operation, {
    Duration? timeout,
    int? maxRetries,
    String? operationName,
  }) async {
    final effectiveTimeout = timeout ?? _defaultTimeout;
    final effectiveRetries = maxRetries ?? _maxRetries;
    final opName = operationName ?? 'API call';

    for (int attempt = 1; attempt <= effectiveRetries; attempt++) {
      try {
        final result = await operation().timeout(effectiveTimeout);
        if (attempt > 1) {
          developer.log('$opName succeeded on attempt $attempt',
              name: 'SupabaseConfig');
        }
        return result;
      } catch (e) {
        final isLastAttempt = attempt == effectiveRetries;
        final shouldRetry = _shouldRetry(e) && !isLastAttempt;

        if (shouldRetry) {
          final delay =
              Duration(milliseconds: 1000 * attempt); // Exponential backoff
          developer.log(
              '$opName failed (attempt $attempt/$effectiveRetries), retrying in ${delay.inSeconds}s: $e',
              name: 'SupabaseConfig',
              level: 800);
          await Future.delayed(delay);
        } else {
          developer.log('$opName failed permanently after $attempt attempts',
              error: e, name: 'SupabaseConfig', level: 900);
          throw SupabaseApiException.fromError(e, operationName: opName);
        }
      }
    }

    throw SupabaseApiException('Maximum retries exceeded for $opName');
  }

  /// Determine if an error is retryable
  static bool _shouldRetry(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('timeout') ||
        errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('temporarily unavailable') ||
        errorStr.contains('502') ||
        errorStr.contains('503') ||
        errorStr.contains('504');
  }

  static Duration get longTimeout => _longTimeout;
}

/// 📦 Standardized API Exception
class SupabaseApiException implements Exception {
  final String message;
  final String? operationName;
  final dynamic originalError;
  final bool isRetryable;
  final bool isNetworkError;
  final bool isAuthError;

  const SupabaseApiException(
    this.message, {
    this.operationName,
    this.originalError,
    this.isRetryable = false,
    this.isNetworkError = false,
    this.isAuthError = false,
  });

  factory SupabaseApiException.fromError(dynamic error,
      {String? operationName}) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('invalid login credentials') ||
        errorStr.contains('jwt') ||
        errorStr.contains('token is expired') ||
        errorStr.contains('not_authorized') ||
        errorStr.contains('refresh_token_not_found')) {
      return SupabaseApiException(
        'Authentication failed. Please log in again.',
        operationName: operationName,
        originalError: error,
        isAuthError: true,
      );
    }

    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return SupabaseApiException(
        'Network error. Please check your connection and try again.',
        operationName: operationName,
        originalError: error,
        isNetworkError: true,
        isRetryable: true,
      );
    }

    if (errorStr.contains('timeout')) {
      return SupabaseApiException(
        'Request timed out. Please try again.',
        operationName: operationName,
        originalError: error,
        isRetryable: true,
      );
    }

    if (errorStr.contains('row level security')) {
      return SupabaseApiException(
        'Access denied. You don\'t have permission for this action.',
        operationName: operationName,
        originalError: error,
        isAuthError: true,
      );
    }

    return SupabaseApiException(
      'An unexpected error occurred: ${error.toString()}',
      operationName: operationName,
      originalError: error,
    );
  }

  @override
  String toString() => message;
}
