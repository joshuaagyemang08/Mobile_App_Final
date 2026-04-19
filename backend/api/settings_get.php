<?php

declare(strict_types=1);

require_once __DIR__ . '/../lib/bootstrap.php';

focuslock_require_method('GET');
$pdo = focuslock_db();
$auth = focuslock_authenticate($pdo);

$userId = (int) $auth['user_id'];
$user = [
    'id' => $userId,
    'email' => (string) $auth['email'],
    'displayName' => (string) ($auth['display_name'] ?? ''),
];
$settings = focuslock_fetch_settings($pdo, $userId);
$settingsPayload = focuslock_settings_payload($settings);
$settingsPayload['userName'] = $user['displayName'];

focuslock_send_json(200, [
    'success' => true,
    'user' => $user,
    'settings' => $settingsPayload,
]);
