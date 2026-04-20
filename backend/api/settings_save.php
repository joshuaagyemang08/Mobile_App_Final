<?php

declare(strict_types=1);

require_once __DIR__ . '/../lib/bootstrap.php';

focuslock_require_method('POST');
$pdo = focuslock_db();
$auth = focuslock_authenticate($pdo);
$body = focuslock_read_json_body();

$userId = (int) $auth['user_id'];
$userName = trim((string) ($body['userName'] ?? $auth['display_name'] ?? ''));
$dailyLimitMinutes = (int) ($body['dailyLimitMinutes'] ?? 60);
$cooldownMinutes = (int) ($body['cooldownMinutes'] ?? 30);
$extraUnlockMinutes = (int) ($body['extraUnlockMinutes'] ?? 15);
$maxUnlocksPerDay = (int) ($body['maxUnlocksPerDay'] ?? 1);
$monitoredApps = $body['monitoredApps'] ?? [];
$lockScheduleEnabled = !empty($body['lockScheduleEnabled']);
$scheduleStartHour = (int) ($body['scheduleStartHour'] ?? 8);
$scheduleStartMinute = (int) ($body['scheduleStartMinute'] ?? 0);
$scheduleEndHour = (int) ($body['scheduleEndHour'] ?? 22);
$scheduleEndMinute = (int) ($body['scheduleEndMinute'] ?? 0);
$accelerometerEnabled = !empty($body['accelerometerEnabled']);
$wakeHour = (int) ($body['wakeHour'] ?? 7);
$wakeMinute = (int) ($body['wakeMinute'] ?? 0);
$sleepHour = (int) ($body['sleepHour'] ?? 23);
$sleepMinute = (int) ($body['sleepMinute'] ?? 0);
$notificationsEnabled = !empty($body['notificationsEnabled']);

if (!is_array($monitoredApps)) {
    $monitoredApps = [];
}

$settingsJson = json_encode(array_values(array_map('strval', $monitoredApps)), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);

$sql = 'INSERT INTO user_settings (
    user_id,
    daily_limit_minutes,
    cooldown_minutes,
    extra_unlock_minutes,
    max_unlocks_per_day,
    monitored_apps_json,
    lock_schedule_enabled,
    schedule_start_hour,
    schedule_start_minute,
    schedule_end_hour,
    schedule_end_minute,
    accelerometer_enabled,
    wake_hour,
    wake_minute,
    sleep_hour,
    sleep_minute,
    notifications_enabled
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON DUPLICATE KEY UPDATE
    daily_limit_minutes = VALUES(daily_limit_minutes),
    cooldown_minutes = VALUES(cooldown_minutes),
    extra_unlock_minutes = VALUES(extra_unlock_minutes),
    max_unlocks_per_day = VALUES(max_unlocks_per_day),
    monitored_apps_json = VALUES(monitored_apps_json),
    lock_schedule_enabled = VALUES(lock_schedule_enabled),
    schedule_start_hour = VALUES(schedule_start_hour),
    schedule_start_minute = VALUES(schedule_start_minute),
    schedule_end_hour = VALUES(schedule_end_hour),
    schedule_end_minute = VALUES(schedule_end_minute),
    accelerometer_enabled = VALUES(accelerometer_enabled),
    wake_hour = VALUES(wake_hour),
    wake_minute = VALUES(wake_minute),
    sleep_hour = VALUES(sleep_hour),
    sleep_minute = VALUES(sleep_minute),
    notifications_enabled = VALUES(notifications_enabled)';

try {
    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        $userId,
        $dailyLimitMinutes,
        $cooldownMinutes,
        $extraUnlockMinutes,
        $maxUnlocksPerDay,
        $settingsJson,
        $lockScheduleEnabled ? 1 : 0,
        $scheduleStartHour,
        $scheduleStartMinute,
        $scheduleEndHour,
        $scheduleEndMinute,
        $accelerometerEnabled ? 1 : 0,
        $wakeHour,
        $wakeMinute,
        $sleepHour,
        $sleepMinute,
        $notificationsEnabled ? 1 : 0,
    ]);
} catch (Exception $e) {
    focuslock_send_json(500, [
        'success' => false,
        'message' => 'Failed to save settings: ' . $e->getMessage(),
    ]);
}

try {
    $updateUser = $pdo->prepare('UPDATE users SET display_name = ? WHERE id = ?');
    $updateUser->execute([$userName !== '' ? $userName : null, $userId]);
} catch (Exception $e) {
    focuslock_send_json(500, [
        'success' => false,
        'message' => 'Failed to update user: ' . $e->getMessage(),
    ]);
}

$settings = focuslock_sync_unlock_state($pdo, $userId);
$settingsPayload = focuslock_settings_payload($settings);
$settingsPayload['userName'] = $userName;

focuslock_send_json(200, [
    'success' => true,
    'message' => 'Settings saved.',
    'user' => [
        'id' => $userId,
        'email' => (string) $auth['email'],
        'displayName' => $userName,
    ],
    'settings' => $settingsPayload,
    'lockState' => focuslock_lock_state_payload($settings),
]);
