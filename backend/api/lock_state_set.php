<?php

declare(strict_types=1);

require_once __DIR__ . '/../lib/bootstrap.php';

focuslock_require_method('POST');
$pdo = focuslock_db();
$auth = focuslock_authenticate($pdo);
$body = focuslock_read_json_body();

$userId = (int) $auth['user_id'];
$locked = !empty($body['locked']);

$pdo->beginTransaction();
try {
    $settings = focuslock_sync_unlock_state($pdo, $userId, true);
    if (!$settings) {
        throw new RuntimeException('Missing settings row for user.');
    }

    if ($locked) {
        $now = new DateTimeImmutable('now');
        $existingRaw = $settings['cooldown_end_at'] ?? null;
        $existingActive = false;

        if (is_string($existingRaw) && trim($existingRaw) !== '') {
            $existingAt = new DateTimeImmutable($existingRaw);
            $existingActive = $existingAt > $now;
        }

        // Preserve an already-active cooldown to avoid extension on repeated lock checks.
        if (!$existingActive) {
            $cooldownMinutes = max(1, (int) ($settings['cooldown_minutes'] ?? 30));
            $endAt = $now->modify('+' . $cooldownMinutes . ' minutes')->format('Y-m-d H:i:s');
            $update = $pdo->prepare('UPDATE user_settings SET cooldown_end_at = ? WHERE user_id = ?');
            $update->execute([$endAt, $userId]);
            $settings['cooldown_end_at'] = $endAt;
        }
    } else {
        $update = $pdo->prepare('UPDATE user_settings SET cooldown_end_at = NULL WHERE user_id = ?');
        $update->execute([$userId]);
        $settings['cooldown_end_at'] = null;
    }

    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    focuslock_send_json(500, [
        'success' => false,
        'message' => 'Failed to update lock state: ' . $e->getMessage(),
    ]);
}

$latest = focuslock_sync_unlock_state($pdo, $userId);
focuslock_send_json(200, [
    'success' => true,
    'lockState' => focuslock_lock_state_payload($latest),
]);
