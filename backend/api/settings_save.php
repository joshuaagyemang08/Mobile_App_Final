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
$scheduleEndHour = (int) ($body['scheduleEndHour'] ?? 22);
$accelerometerEnabled = !empty($body['accelerometerEnabled']);
$wakeHour = (int) ($body['wakeHour'] ?? 7);
$sleepHour = (int) ($body['sleepHour'] ?? 23);

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
    schedule_end_hour,
    accelerometer_enabled,
    wake_hour,
    sleep_hour
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON DUPLICATE KEY UPDATE
    daily_limit_minutes = VALUES(daily_limit_minutes),
    cooldown_minutes = VALUES(cooldown_minutes),
    extra_unlock_minutes = VALUES(extra_unlock_minutes),
    max_unlocks_per_day = VALUES(max_unlocks_per_day),
    monitored_apps_json = VALUES(monitored_apps_json),
    lock_schedule_enabled = VALUES(lock_schedule_enabled),
    schedule_start_hour = VALUES(schedule_start_hour),
    schedule_end_hour = VALUES(schedule_end_hour),
    accelerometer_enabled = VALUES(accelerometer_enabled),
    wake_hour = VALUES(wake_hour),
    sleep_hour = VALUES(sleep_hour)';

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
    $scheduleEndHour,
    $accelerometerEnabled ? 1 : 0,
    $wakeHour,
    $sleepHour,
]);

$updateUser = $pdo->prepare('UPDATE users SET display_name = ? WHERE id = ?');
$updateUser->execute([$userName !== '' ? $userName : null, $userId]);

$settings = focuslock_fetch_settings($pdo, $userId);
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
]);
