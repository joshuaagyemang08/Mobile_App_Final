<?php

declare(strict_types=1);

require_once __DIR__ . '/../lib/bootstrap.php';

focuslock_require_method('POST');
$pdo = focuslock_db();
$body = focuslock_read_json_body();

$email = mb_strtolower(trim((string) ($body['email'] ?? '')));
$password = (string) ($body['password'] ?? '');
$displayName = trim((string) ($body['displayName'] ?? ''));

if ($email === '' || $password === '') {
    focuslock_send_json(400, ['success' => false, 'message' => 'Email and password are required.']);
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    focuslock_send_json(400, ['success' => false, 'message' => 'Enter a valid email address.']);
}

if (mb_strlen($password) < 6) {
    focuslock_send_json(400, ['success' => false, 'message' => 'Password must be at least 6 characters.']);
}

$existing = focuslock_find_user_by_email($pdo, $email);
$passwordHash = password_hash($password, PASSWORD_DEFAULT);

if ($existing) {
    if ((int) $existing['email_verified'] === 1) {
        focuslock_send_json(409, ['success' => false, 'message' => 'Account already exists.']);
    }

    $update = $pdo->prepare('UPDATE users SET password_hash = ?, display_name = ?, email_verified = 0 WHERE id = ?');
    $update->execute([$passwordHash, $displayName !== '' ? $displayName : null, $existing['id']]);
    $userId = (int) $existing['id'];
} else {
    $insert = $pdo->prepare('INSERT INTO users (email, password_hash, display_name, email_verified) VALUES (?, ?, ?, 0)');
    $insert->execute([$email, $passwordHash, $displayName !== '' ? $displayName : null]);
    $userId = (int) $pdo->lastInsertId();
}

$otp = focuslock_generate_code();
$otpHash = focuslock_hash_secret($otp);
$expiresAt = (new DateTimeImmutable('now'))
    ->modify('+' . (int) focuslock_config('otp_ttl_minutes') . ' minutes')
    ->format('Y-m-d H:i:s');

$pdo->prepare('DELETE FROM otp_codes WHERE user_id = ? AND purpose = ?')->execute([$userId, 'signup']);
$insertOtp = $pdo->prepare('INSERT INTO otp_codes (user_id, purpose, code_hash, expires_at) VALUES (?, ?, ?, ?)');
$insertOtp->execute([$userId, 'signup', $otpHash, $expiresAt]);

$subject = 'Your FocusLock verification code';
$message = "Your FocusLock verification code is: {$otp}\n\nIt expires in " . (int) focuslock_config('otp_ttl_minutes') . " minutes.";
focuslock_send_email($email, $subject, $message);

focuslock_send_json(201, [
    'success' => true,
    'message' => 'Account created. Verification code sent to your email.',
    'requiresOtp' => true,
    'email' => $email,
]);
