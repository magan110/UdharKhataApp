// Stable message keys are shared with the API. Hindi resources arrive in D18.
String errorMessage(String key) => switch (key) {
  'ledger.cacheTooLarge' => 'This ledger is too large to save offline. View confirmed server history while online.',
  'ledger.localOverpayment' => 'Payment exceeds the locally known balance. Review the amount before saving.',
  'ledger.cacheRequired' => 'Open this customer online to verify and save their ledger before recording offline entries.',
  'api.cursorInvalid' =>
    'This snapshot has expired. Refresh to open the latest records.',
  'history.invalidResponse' =>
    'The server records could not be verified. Refresh and try again.',
  'history.failed' =>
    'Could not load the records. Check your connection and try again.',
  'api.capacityUnavailable' =>
    'The server cannot provide this total right now. Please try again later.',
  'payment.pending' => 'Check the saved payment before entering another credit or payment for this customer.',
  'payment.creditPending' =>
    'Check the saved credit before recording a payment for this customer.',
  'payment.savedInvalid' => 'The saved payment cannot be read. Keep this app data and contact support before entering it again.',
  'payment.invalid' =>
    'Use a positive amount up to ₹1,00,000 and select Cash or UPI.',
  'payment.balanceConflict' => 'This payment was rejected because it exceeds the current balance or ledger limit. Refresh the balance and review the amount.',
  'payment.failed' => 'Could not verify this payment. Check the same saved request; do not enter it again.',
  'credit.pending' =>
    'Check the saved credit before entering another credit for this customer.',
  'credit.savedInvalid' => 'The saved credit cannot be read. Keep this app data and contact support before entering this credit again.',
  'credit.invalid' => 'Use a positive amount up to ₹1,00,000, a note up to 500 characters, and a valid due date.',
  'credit.clockInvalid' =>
    'Check your phone date and time. The saved request is retained for review.',
  'credit.balanceLimit' => 'This credit exceeds the supported ledger balance. The saved request needs attention.',
  'credit.failed' => 'Could not verify this credit. Check the same saved request; do not enter it again.',
  'link.internetNeeded' => 'Internet is needed to identify and add this customer. Connect and try again.',
  'qr.invalid' => 'This is not a valid Udhaar Khata customer QR.',
  'qr.unsupported' =>
    'This QR version is not supported. Ask for a current customer QR.',
  'qr.revoked' =>
    'This QR is no longer active. Ask the customer for their current QR.',
  'api.notFound' =>
    'This shop or customer is no longer available to your account.',
  'api.idempotencyConflict' => 'This request conflicts with an earlier confirmation. Refresh the customer list before trying again.',
  'api.invalidResponse' =>
    'The response could not be verified. Check the same request again.',
  'link.pending' =>
    'Check your previous customer confirmation before scanning another QR.',
  'link.savedRequestInvalid' => 'Your saved confirmation could not be read. Contact support before trying to add another customer.',
  'link.nicknameInvalid' => 'Use a shop nickname of at most 120 characters.',
  'link.failed' =>
    'Could not confirm the customer. Check your connection and try again.',
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
