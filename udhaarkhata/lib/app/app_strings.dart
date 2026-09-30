// Stable message keys are shared with the API. Hindi resources arrive in D18.
String errorMessage(String key) => switch (key) {
  'auth.required' => 'Please sign in to continue.',
  'auth.forbidden' => 'You do not have access to this page.',
  'api.networkError' =>
    'Could not connect. Check your connection and try again.',
  _ => 'Could not open your account. Please try again.',
};
