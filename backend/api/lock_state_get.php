<?php

declare(strict_types=1);

require_once __DIR__ . '/../lib/bootstrap.php';

focuslock_require_method('GET');
$pdo = focuslock_db();
$auth = focuslock_authenticate($pdo);

$userId = (int) $auth['user_id'];
$settings = focuslock_sync_unlock_state($pdo, $userId);

focuslock_send_json(200, [
    'success' => true,
    'lockState' => focuslock_lock_state_payload($settings),
]);
