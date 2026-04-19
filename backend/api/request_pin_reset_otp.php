<?php

declare(strict_types=1);

require_once __DIR__ . '/../lib/bootstrap.php';

focuslock_require_method('POST');
$pdo = focuslock_db();
$auth = focuslock_authenticate($pdo);

$userId = (int) $auth['user_id'];
$email = (string) $auth['email'];

$otp = focuslock_generate_code();
$otpHash = focuslock_hash_secret($otp);
$expiresAt = (new DateTimeImmutable('now'))
    ->modify('+' . (int) focuslock_config('otp_ttl_minutes') . ' minutes')
    ->format('Y-m-d H:i:s');

$pdo->prepare('DELETE FROM otp_codes WHERE user_id = ? AND purpose = ?')->execute([$userId, 'pin_reset']);
$insertOtp = $pdo->prepare('INSERT INTO otp_codes (user_id, purpose, code_hash, expires_at) VALUES (?, ?, ?, ?)');
$insertOtp->execute([$userId, 'pin_reset', $otpHash, $expiresAt]);

$subject = 'Your FocusLock PIN reset code';
$message = "Your FocusLock PIN reset code is: {$otp}\n\nIt expires in " . (int) focuslock_config('otp_ttl_minutes') . " minutes.";
focuslock_send_email($email, $subject, $message);

focuslock_send_json(200, [
    'success' => true,
    'message' => 'PIN reset code sent to your email.',
]);
