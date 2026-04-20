<?php

declare(strict_types=1);

require_once __DIR__ . '/../lib/bootstrap.php';

focuslock_require_method('POST');
$pdo = focuslock_db();
$auth = focuslock_authenticate($pdo);

$userId = (int) $auth['user_id'];

$pdo->beginTransaction();
try {
    $settings = focuslock_sync_unlock_state($pdo, $userId, true);
    if (!$settings) {
        throw new RuntimeException('Missing settings row for user.');
    }

    $now = new DateTimeImmutable('now');
    $maxUnlocks = max(1, (int) ($settings['max_unlocks_per_day'] ?? 1));
    $used = (int) ($settings['unlocks_used_today'] ?? 0);

    $cooldownRaw = $settings['cooldown_end_at'] ?? null;
    if (is_string($cooldownRaw) && trim($cooldownRaw) !== '') {
        $cooldownAt = new DateTimeImmutable($cooldownRaw);
        if ($cooldownAt > $now) {
            $remaining = $cooldownAt->getTimestamp() - $now->getTimestamp();
            $pdo->commit();
            focuslock_send_json(409, [
                'success' => false,
                'message' => 'Cooldown is still active.',
                'lockState' => focuslock_lock_state_payload($settings),
                'cooldownRemainingSeconds' => max(0, $remaining),
            ]);
        }
    }

    if ($used >= $maxUnlocks) {
        $pdo->commit();
        focuslock_send_json(409, [
            'success' => false,
            'message' => 'Daily unlock limit reached.',
            'lockState' => focuslock_lock_state_payload($settings),
        ]);
    }

    $nextUsed = $used + 1;
    $update = $pdo->prepare('UPDATE user_settings SET unlocks_used_today = ?, cooldown_end_at = NULL WHERE user_id = ?');
    $update->execute([$nextUsed, $userId]);

    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    focuslock_send_json(500, [
        'success' => false,
        'message' => 'Failed to consume unlock: ' . $e->getMessage(),
    ]);
}

$latest = focuslock_sync_unlock_state($pdo, $userId);
focuslock_send_json(200, [
    'success' => true,
    'message' => 'Unlock consumed.',
    'lockState' => focuslock_lock_state_payload($latest),
]);
