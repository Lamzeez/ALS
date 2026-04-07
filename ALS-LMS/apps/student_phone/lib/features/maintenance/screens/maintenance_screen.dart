import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';

/// "System Under Maintenance" / "Network Locked" screen displayed
/// when the Dev Admin activates the kill switch or maintenance mode.
/// Local offline studying (via SQLite) remains available.
class MaintenanceScreen extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onStudyOffline;

  const MaintenanceScreen({
    super.key,
    this.message = 'System Under Maintenance',
    this.onRetry,
    this.onStudyOffline,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = message.toLowerCase().contains('locked');
    final icon = isLocked ? Icons.lock_outlined : Icons.construction_rounded;
    final iconColor = isLocked ? AlsColors.error : AlsColors.warning;

    return Scaffold(
      backgroundColor: AlsColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated icon container
                TweenAnimationBuilder<double>(
                  duration: const Duration(seconds: 2),
                  tween: Tween(begin: 0, end: 1),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: iconColor.withValues(alpha: 0.3),
                        width: 3,
                      ),
                    ),
                    child: Icon(icon, size: 64, color: iconColor),
                  ),
                ),
                const SizedBox(height: 36),

                // Title
                Text(
                  isLocked ? 'Network Locked' : 'System Under Maintenance',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AlsColors.textPrimary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Message
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AlsColors.textSecondary,
                        height: 1.5,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'You can still study your downloaded content offline.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AlsColors.textHint,
                        fontStyle: FontStyle.italic,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Study Offline button
                if (onStudyOffline != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onStudyOffline,
                      icon: const Icon(Icons.download_done_rounded),
                      label: const Text('Study Offline'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AlsColors.secondary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                if (onStudyOffline != null) const SizedBox(height: 12),

                // Retry button
                if (onRetry != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry Connection'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
