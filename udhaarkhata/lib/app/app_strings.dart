// Stable message keys are shared with the API. Hindi resources arrive in D18.
String errorMessage(String key) => switch (key) {
  'auth.required' => 'Please sign in to continue.',
  'auth.forbidden' => 'You do not have access to this page.',
  'auth.cancelled' => 'Sign-in was cancelled. You can try again.',
  'auth.identityInvalid' =>
    'Google sign-in expired or could not be verified. Please sign in again.',
  'auth.roleConflict' => 'This Google account already has a different role. Choose its original role.',
  'api.rateLimited' => 'Too many attempts. Please wait and try again.',
  'api.networkError' =>
    'Could not connect. Check your connection and try again.',
  'qr.recoveryRequired' => 'Connect to the internet and refresh your QR. Its replacement could not be confirmed, so the saved QR is hidden.',
  'api.featureUnavailable' =>
    'This feature is not available yet. Please try again later.',
  'qr.rotationRecovered' => 'The replacement response could not be confirmed. The latest QR from the server is shown.',
  _ => 'Could not open your account. Please try again.',
};
