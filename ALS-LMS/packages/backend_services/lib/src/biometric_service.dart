import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricTypeKey = 'biometric_type';

  Future<bool> isBiometricAvailable() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } on PlatformException {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  Future<bool> isBiometricEnabled() async {
    final value = await _secureStorage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _secureStorage.write(
      key: _biometricEnabledKey,
      value: enabled.toString(),
    );
  }

  Future<bool> verifyBiometric({String reason = 'Verify your identity'}) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  Future<bool> setupBiometric() async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      final verified = await verifyBiometric(
        reason: 'Set up biometric login for ALS Study',
      );

      if (verified) {
        final biometrics = await getAvailableBiometrics();
        String biometricType = 'fingerprint';
        if (biometrics.contains(BiometricType.face)) {
          biometricType = 'face';
        } else if (biometrics.contains(BiometricType.iris)) {
          biometricType = 'iris';
        }

        await _secureStorage.write(
            key: _biometricTypeKey, value: biometricType);
        await setBiometricEnabled(true);
        return true;
      }
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> disableBiometric() async {
    await setBiometricEnabled(false);
    await _secureStorage.delete(key: _biometricTypeKey);
  }

  /// 🔒 SECURITY: Clear all biometric data on logout
  /// This prevents unauthorized access on shared devices
  Future<void> clearBiometricDataOnLogout() async {
    try {
      await _secureStorage.delete(key: _biometricEnabledKey);
      await _secureStorage.delete(key: _biometricTypeKey);
      // Clear any other biometric-related secure storage keys
      await _secureStorage.deleteAll();
    } catch (e) {
      // Log but don't throw - logout should still proceed
      print('[SECURITY] Failed to clear biometric data on logout: $e');
    }
  }

  Future<String?> getBiometricType() async {
    return await _secureStorage.read(key: _biometricTypeKey);
  }
}
