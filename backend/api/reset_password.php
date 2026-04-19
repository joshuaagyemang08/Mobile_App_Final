<?php

declare(strict_types=1);

require_once __DIR__ . '/../lib/bootstrap.php';

focuslock_require_method('POST');
$pdo = focuslock_db();
$body = focuslock_read_json_body();

$email = mb_strtolower(trim((string) ($body['email'] ?? '')));
$code = trim((string) ($body['code'] ?? ''));
$newPassword = (string) ($body['newPassword'] ?? '');

if ($email === '' || $code === '' || $newPassword === '') {
    focuslock_send_json(400, ['success' => false, 'message' => 'Email, code, and new password are required.']);
}

if (mb_strlen($newPassword) < 6) {
    focuslock_send_json(400, ['success' => false, 'message' => 'Password must be at least 6 characters.']);
}

$user = focuslock_find_user_by_email($pdo, $email);
if (!$user) {
    focuslock_send_json(404, ['success' => false, 'message' => 'Account not found.']);
}

$stmt = $pdo->prepare('SELECT * FROM otp_codes WHERE user_id = ? AND purpose = ? AND consumed_at IS NULL AND expires_at > NOW() ORDER BY created_at DESC LIMIT 1');
$stmt->execute([(int) $user['id'], 'password_reset']);
$otpRow = $stmt->fetch();

if (!$otpRow) {
    focuslock_send_json(400, ['success' => false, 'message' => 'OTP code expired or missing.']);
}

if ((int) $otpRow['attempts'] >= 5) {
    focuslock_send_json(429, ['success' => false, 'message' => 'Too many attempts. Request a new code.']);
}

$attemptsUpdate = $pdo->prepare('UPDATE otp_codes SET attempts = attempts + 1 WHERE id = ?');
$attemptsUpdate->execute([(int) $otpRow['id']]);

$codeHash = focuslock_hash_secret($code);
if (!hash_equals((string) $otpRow['code_hash'], $codeHash)) {
    focuslock_send_json(400, ['success' => false, 'message' => 'Invalid OTP code.']);
}

$passwordHash = password_hash($newPassword, PASSWORD_DEFAULT);
$update = $pdo->prepare('UPDATE users SET password_hash = ? WHERE id = ?');
$update->execute([$passwordHash, (int) $user['id']]);

$consume = $pdo->prepare('UPDATE otp_codes SET consumed_at = NOW() WHERE id = ?');
$consume->execute([(int) $otpRow['id']]);

focuslock_send_json(200, [
    'success' => true,
    'message' => 'Password reset successful. You can now sign in.',
]);
