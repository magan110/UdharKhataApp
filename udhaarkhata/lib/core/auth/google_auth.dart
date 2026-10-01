import 'package:google_sign_in/google_sign_in.dart';

import '../network/app_failure.dart';

const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
Future<void>? _initialization;
Future<String> googleIdToken() async {
  if (googleServerClientId.isEmpty) {
    throw const AppFailure('FEATURE_UNAVAILABLE', 'api.featureUnavailable');
  }
  try {
    await (_initialization ??= GoogleSignIn.instance.initialize(
      serverClientId: googleServerClientId,
    ));
    final account = await GoogleSignIn.instance.authenticate();
    final token = account.authentication.idToken;
    if (token == null) {
      throw const AppFailure('IDENTITY_INVALID', 'auth.identityInvalid');
    }
    return token;
  } on GoogleSignInException catch (error) {
    if (error.code == GoogleSignInExceptionCode.canceled) {
      throw const AppFailure('SIGN_IN_CANCELLED', 'auth.cancelled');
    }
    throw const AppFailure('IDENTITY_INVALID', 'auth.identityInvalid');
  }
}
