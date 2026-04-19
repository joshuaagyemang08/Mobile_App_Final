<?php

declare(strict_types=1);

require_once __DIR__ . '/../lib/bootstrap.php';

focuslock_require_method('POST');
$pdo = focuslock_db();
$body = focuslock_read_json_body();

$email = mb_strtolower(trim((string) ($body['email'] ?? '')));
$password = (string) ($body['password'] ?? '');

if ($email === '' || $password === '') {
    focuslock_send_json(400, ['success' => false, 'message' => 'Email and password are required.']);
}

$user = focuslock_find_user_by_email($pdo, $email);
if (!$user || !password_verify($password, (string) $user['password_hash'])) {
    focuslock_send_json(401, ['success' => false, 'message' => 'Invalid email or password.']);
}

if ((int) $user['email_verified'] !== 1) {
    focuslock_send_json(403, [
        'success' => false,
        'message' => 'Email not verified. Request a verification code first.',
        'requiresOtp' => true,
        'email' => $email,
    ]);
}

focuslock_ensure_settings($pdo, (int) $user['id']);
$token = focuslock_issue_token($pdo, (int) $user['id']);
$settings = focuslock_fetch_settings($pdo, (int) $user['id']);

focuslock_send_json(200, [
    'success' => true,
    'message' => 'Login successful.',
    'token' => $token,
    'user' => [
        'id' => (int) $user['id'],
        'email' => $email,
        'displayName' => $user['display_name'] ?? '',
    ],
    'settings' => focuslock_settings_payload($settings),
]);
