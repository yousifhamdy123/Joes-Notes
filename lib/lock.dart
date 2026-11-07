import 'package:local_auth/local_auth.dart';

import 'l10n.dart';

final _auth = LocalAuthentication();

/// True when the phone has a fingerprint / PIN / pattern set up.
Future<bool> deviceCanAuth() async {
  try {
    return await _auth.isDeviceSupported();
  } catch (_) {
    return false;
  }
}

/// Asks for fingerprint or the phone's PIN / pattern.
Future<bool> authenticate() async {
  try {
    return await _auth.authenticate(
      localizedReason: t('auth_reason'),
      options: const AuthenticationOptions(stickyAuth: true),
    );
  } catch (_) {
    return false;
  }
}
