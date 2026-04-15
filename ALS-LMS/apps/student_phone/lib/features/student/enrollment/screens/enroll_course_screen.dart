import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_services/shared_services.dart';
import 'package:shared_ui/shared_ui.dart';

/// Screen for students to enroll in a course by scanning a QR code.
/// A PIN-entry dialog is available as a fallback via "Enter PIN instead".
class EnrollCourseScreen extends StatefulWidget {
  const EnrollCourseScreen({super.key});

  @override
  State<EnrollCourseScreen> createState() => _EnrollCourseScreenState();
}

class _EnrollCourseScreenState extends State<EnrollCourseScreen> {
  final _courseService = CourseService();
  bool _isLoading = false;
  bool _scannedHandled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan to Join'),
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                if (_scannedHandled || _isLoading) return;
                final code = capture.barcodes.firstOrNull?.rawValue;
                if (code == null || code.isEmpty) return;
                setState(() => _scannedHandled = true);
                _enrollByPin(pin: code);
              },
            ),
          ),
          Container(
            color: AlsColors.primarySurface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.qr_code_scanner_rounded,
                    color: AlsColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Point camera at teacher\'s QR code to join instantly.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AlsColors.textSecondary,
                        ),
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextButton.icon(
              onPressed: _isLoading ? null : _showPinDialog,
              icon: const Icon(Icons.pin_outlined),
              label: const Text('Enter PIN instead'),
            ),
          ),
        ],
      ),
    );
  }

  void _showPinDialog() {
    final pinController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Enter Course PIN'),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 10,
            ),
            decoration: const InputDecoration(
              hintText: '000000',
              counterText: '',
            ),
            maxLength: 6,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final pin = pinController.text;
                Navigator.pop(ctx);
                _enrollByPin(pin: pin);
              },
              child: const Text('Join'),
            ),
          ],
        );
      },
    ).then((_) => pinController.dispose());
  }

  Future<void> _enrollByPin({required String pin}) async {
    final code = pin.trim();
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid PIN'),
          backgroundColor: AlsColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() => _scannedHandled = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _courseService.enrollByPin(code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Successfully enrolled! 🎉'),
            backgroundColor: AlsColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Failed to enroll';
        final msg = e.toString();
        if (msg.contains('Invalid PIN')) {
          errorMsg = 'Invalid PIN code. Please check with your teacher.';
        } else if (msg.contains('duplicate') || msg.contains('unique')) {
          errorMsg = 'You are already enrolled in this course!';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AlsColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() => _scannedHandled = false);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
