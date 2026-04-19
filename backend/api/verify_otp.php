<?php

declare(strict_types=1);

require_once __DIR__ . '/../lib/bootstrap.php';

focuslock_require_method('POST');
$pdo = focuslock_db();
$body = focuslock_read_json_body();

$email = mb_strtolower(trim((string) ($body['email'] ?? '')));
$code = trim((string) ($body['code'] ?? ''));
$purpose = trim((string) ($body['purpose'] ?? 'signup'));

if ($email === '' || $code === '') {
    focuslock_send_json(400, ['success' => false, 'message' => 'Email and code are required.']);
}

if (!in_array($purpose, ['signup', 'pin_reset'], true)) {
    focuslock_send_json(400, ['success' => false, 'message' => 'Invalid OTP purpose.']);
}

$user = focuslock_find_user_by_email($pdo, $email);
if (!$user) {
    focuslock_send_json(404, ['success' => false, 'message' => 'Account not found.']);
}

$stmt = $pdo->prepare('SELECT * FROM otp_codes WHERE user_id = ? AND purpose = ? AND consumed_at IS NULL AND expires_at > NOW() ORDER BY created_at DESC LIMIT 1');
$stmt->execute([(int) $user['id'], $purpose]);
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

$consume = $pdo->prepare('UPDATE otp_codes SET consumed_at = NOW() WHERE id = ?');
$consume->execute([(int) $otpRow['id']]);

if ($purpose === 'signup') {
    $activate = $pdo->prepare('UPDATE users SET email_verified = 1 WHERE id = ?');
    $activate->execute([(int) $user['id']]);

    focuslock_ensure_settings($pdo, (int) $user['id']);
    $token = focuslock_issue_token($pdo, (int) $user['id']);
    $settings = focuslock_fetch_settings($pdo, (int) $user['id']);

    focuslock_send_json(200, [
        'success' => true,
        'message' => 'Email verified successfully.',
        'token' => $token,
        'user' => [
            'id' => (int) $user['id'],
            'email' => $email,
            'displayName' => $user['display_name'] ?? '',
        ],
        'settings' => focuslock_settings_payload($settings),
    ]);
}

focuslock_send_json(200, [
    'success' => true,
    'message' => 'PIN reset code verified.',
]);
