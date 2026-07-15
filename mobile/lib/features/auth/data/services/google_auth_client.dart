import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/api_exception.dart';

final googleAuthClientProvider = Provider<GoogleAuthClient>((ref) {
  return NativeGoogleAuthClient();
});

abstract interface class GoogleAuthClient {
  Future<String?> authenticate();

  Future<void> disconnect();
}

class NativeGoogleAuthClient implements GoogleAuthClient {
  NativeGoogleAuthClient({GoogleSignIn? signIn})
    : _signIn = signIn ?? GoogleSignIn.instance;

  final GoogleSignIn _signIn;
  Future<void>? _initialization;

  Future<void> _initialize() {
    return _initialization ??= _signIn.initialize(
      clientId: AppConfig.googleClientId.isEmpty
          ? null
          : AppConfig.googleClientId,
      serverClientId: AppConfig.googleServerClientId.isEmpty
          ? null
          : AppConfig.googleServerClientId,
    );
  }

  @override
  Future<String?> authenticate() async {
    await _initialize();
    if (!_signIn.supportsAuthenticate()) {
      throw const ApiException(
        'Google sign-in is unavailable on this platform.',
      );
    }
    try {
      final account = await _signIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const ApiException(
          'Google did not return an identity token. Check the OAuth client configuration.',
        );
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw const ApiException(
        'Google sign-in could not be completed. Please try again.',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    await _initialize();
    try {
      await _signIn.disconnect();
    } on GoogleSignInException {
      return;
    }
  }
}
