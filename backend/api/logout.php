<?php

declare(strict_types=1);

require_once __DIR__ . '/../lib/bootstrap.php';

focuslock_require_method('POST');
$pdo = focuslock_db();
$auth = focuslock_authenticate($pdo);

$stmt = $pdo->prepare('UPDATE auth_tokens SET revoked_at = NOW() WHERE token_hash = ?');
$stmt->execute([hash('sha256', focuslock_bearer_token() ?? '')]);

focuslock_send_json(200, [
    'success' => true,
    'message' => 'Logged out successfully.',
]);
