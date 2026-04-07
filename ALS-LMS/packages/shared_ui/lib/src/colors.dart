import 'package:flutter/material.dart';

/// ALS-LMS Design System Colors
///
/// Inspired by the Philippine flag colors and education-focused palettes.
/// Uses a calming blue-green primary with warm accents for engagement.
class AlsColors {
  AlsColors._();

  // ── Primary (Deep Ocean Blue - Trust & Education) ──
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primarySurface = Color(0xFFE3F2FD);

  // ── Secondary (Emerald Green - Growth & Progress) ──
  static const Color secondary = Color(0xFF2E7D32);
  static const Color secondaryLight = Color(0xFF66BB6A);
  static const Color secondaryDark = Color(0xFF1B5E20);
  static const Color secondarySurface = Color(0xFFE8F5E9);

  // ── Accent (Golden Yellow - Achievement & Filipino Heritage) ──
  static const Color accent = Color(0xFFF9A825);
  static const Color accentLight = Color(0xFFFFD54F);
  static const Color accentDark = Color(0xFFF57F17);

  // ── Status Colors ──
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF29B6F6);

  // ── Progress & Mastery ──
  static const Color locked = Color(0xFF9E9E9E);
  static const Color inProgress = Color(0xFF42A5F5);
  static const Color completed = Color(0xFF66BB6A);
  static const Color mastered = Color(0xFFFFD54F);

  // ── Risk Levels (At-Risk Detection) ──
  static const Color riskHigh = Color(0xFFE53935);
  static const Color riskMedium = Color(0xFFFFA726);
  static const Color riskLow = Color(0xFF66BB6A);

  // ── Strands (ALS Learning Strands) ──
  static const Color strandCommunication = Color(0xFF42A5F5);
  static const Color strandScience = Color(0xFF26A69A);
  static const Color strandMath = Color(0xFF7E57C2);
  static const Color strandLife = Color(0xFFEF5350);
  static const Color strandDigital = Color(0xFF5C6BC0);
  static const Color strandSociety = Color(0xFFFF7043);

  // ── Neutrals ──
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F2F5);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color shadow = Color(0x1A000000);

  // ── Dark Mode ──
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceVariant = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // ── Online/Offline Indicator ──
  static const Color online = Color(0xFF43A047);
  static const Color offline = Color(0xFFE53935);
  static const Color syncing = Color(0xFFFFA726);
}
