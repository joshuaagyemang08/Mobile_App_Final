<?php

declare(strict_types=1);

require_once __DIR__ . '/../lib/bootstrap.php';

focuslock_require_method('POST');
$pdo = focuslock_db();
$body = focuslock_read_json_body();

$email = mb_strtolower(trim((string) ($body['email'] ?? '')));
if ($email === '') {
    focuslock_send_json(400, ['success' => false, 'message' => 'Email is required.']);
}

$user = focuslock_find_user_by_email($pdo, $email);
if (!$user) {
    focuslock_send_json(404, ['success' => false, 'message' => 'Account not found.']);
}

$otp = focuslock_generate_code();
$otpHash = focuslock_hash_secret($otp);
$expiresAt = (new DateTimeImmutable('now'))
    ->modify('+' . (int) focuslock_config('otp_ttl_minutes') . ' minutes')
    ->format('Y-m-d H:i:s');

$pdo->prepare('DELETE FROM otp_codes WHERE user_id = ? AND purpose = ?')->execute([(int) $user['id'], 'password_reset']);
$insertOtp = $pdo->prepare('INSERT INTO otp_codes (user_id, purpose, code_hash, expires_at) VALUES (?, ?, ?, ?)');
$insertOtp->execute([(int) $user['id'], 'password_reset', $otpHash, $expiresAt]);

$subject = 'Your FocusLock password reset code';
$message = "Your FocusLock password reset code is: {$otp}\n\nIt expires in " . (int) focuslock_config('otp_ttl_minutes') . " minutes.";
focuslock_send_email($email, $subject, $message);

focuslock_send_json(200, [
    'success' => true,
    'message' => 'Password reset code sent to your email.',
]);
