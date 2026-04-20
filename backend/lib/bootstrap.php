<?php

declare(strict_types=1);

$focuslockConfig = require __DIR__ . '/../config.php';

if (!empty($focuslockConfig['timezone'])) {
    date_default_timezone_set((string) $focuslockConfig['timezone']);
}

function focuslock_config(string $key): mixed
{
    global $focuslockConfig;
    return $focuslockConfig[$key] ?? null;
}

function focuslock_db(): PDO
{
    static $pdo = null;
    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $dsn = sprintf(
        'mysql:host=%s;dbname=%s;charset=utf8mb4',
        focuslock_config('db_host'),
        focuslock_config('db_name')
    );

    $pdo = new PDO($dsn, (string) focuslock_config('db_user'), (string) focuslock_config('db_pass'), [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);

    return $pdo;
}

function focuslock_send_json(int $statusCode, array $payload): never
{
    http_response_code($statusCode);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

function focuslock_read_json_body(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') {
        return [];
    }

    $decoded = json_decode($raw, true);
    if (!is_array($decoded)) {
        focuslock_send_json(400, ['success' => false, 'message' => 'Invalid JSON body.']);
    }

    return $decoded;
}

function focuslock_require_method(string $method): void
{
    if (strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET') !== strtoupper($method)) {
        focuslock_send_json(405, ['success' => false, 'message' => 'Method not allowed.']);
    }
}

function focuslock_bearer_token(): ?string
{
    $authorization = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
    if ($authorization === '' && function_exists('apache_request_headers')) {
        $headers = apache_request_headers();
        $authorization = $headers['Authorization'] ?? $headers['authorization'] ?? '';
    }

    if (preg_match('/Bearer\s+(.*)$/i', $authorization, $matches)) {
        return trim($matches[1]);
    }

    return null;
}

function focuslock_generate_code(): string
{
    $length = (int) focuslock_config('otp_length');
    $min = (int) pow(10, $length - 1);
    $max = (int) pow(10, $length) - 1;
    return (string) random_int($min, $max);
}

function focuslock_hash_secret(string $value): string
{
    $secretKey = (string) focuslock_config('secret_key');
    return hash_hmac('sha256', $value, $secretKey);
}

function focuslock_send_email(string $to, string $subject, string $message): bool
{
    $fromEmail = (string) focuslock_config('mail_from');
    $fromName = (string) focuslock_config('mail_from_name');
    $headers = [
        'MIME-Version: 1.0',
        'Content-Type: text/plain; charset=UTF-8',
        'From: ' . $fromName . ' <' . $fromEmail . '>',
    ];

    return mail($to, $subject, $message, implode("\r\n", $headers));
}

function focuslock_find_user_by_email(PDO $pdo, string $email): ?array
{
    $stmt = $pdo->prepare('SELECT * FROM users WHERE email = ? LIMIT 1');
    $stmt->execute([mb_strtolower(trim($email))]);
    $user = $stmt->fetch();
    return $user ?: null;
}

function focuslock_issue_token(PDO $pdo, int $userId): string
{
    $plainToken = bin2hex(random_bytes(32));
    $tokenHash = hash('sha256', $plainToken);
    $expiresAt = (new DateTimeImmutable('now'))
        ->modify('+' . (int) focuslock_config('token_ttl_hours') . ' hours')
        ->format('Y-m-d H:i:s');

    $stmt = $pdo->prepare('INSERT INTO auth_tokens (user_id, token_hash, expires_at) VALUES (?, ?, ?)');
    $stmt->execute([$userId, $tokenHash, $expiresAt]);

    return $plainToken;
}

function focuslock_authenticate(PDO $pdo): array
{
    $token = focuslock_bearer_token();
    if ($token === null || $token === '') {
        focuslock_send_json(401, ['success' => false, 'message' => 'Missing bearer token.']);
    }

    $tokenHash = hash('sha256', $token);
    $stmt = $pdo->prepare('SELECT t.*, u.id AS user_id, u.email, u.display_name, u.email_verified FROM auth_tokens t INNER JOIN users u ON u.id = t.user_id WHERE t.token_hash = ? AND t.revoked_at IS NULL AND t.expires_at > NOW() LIMIT 1');
    $stmt->execute([$tokenHash]);
    $row = $stmt->fetch();

    if (!$row) {
        focuslock_send_json(401, ['success' => false, 'message' => 'Invalid or expired session.']);
    }

    return $row;
}

function focuslock_ensure_settings(PDO $pdo, int $userId): void
{
    $stmt = $pdo->prepare('SELECT id FROM user_settings WHERE user_id = ? LIMIT 1');
    $stmt->execute([$userId]);
    if ($stmt->fetch()) {
        return;
    }

    $defaultApps = json_encode([], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    $insert = $pdo->prepare('INSERT INTO user_settings (user_id, monitored_apps_json) VALUES (?, ?)');
    $insert->execute([$userId, $defaultApps]);
}

function focuslock_today_key(): string
{
    return (new DateTimeImmutable('now'))->format('Y-m-d');
}

function focuslock_fetch_settings(PDO $pdo, int $userId): array
{
    focuslock_ensure_settings($pdo, $userId);
    $stmt = $pdo->prepare('SELECT * FROM user_settings WHERE user_id = ? LIMIT 1');
    $stmt->execute([$userId]);
    $settings = $stmt->fetch();

    return $settings ?: [];
}

function focuslock_sync_unlock_state(PDO $pdo, int $userId, bool $forUpdate = false): array
{
    focuslock_ensure_settings($pdo, $userId);

    $sql = 'SELECT * FROM user_settings WHERE user_id = ? LIMIT 1';
    if ($forUpdate) {
        $sql .= ' FOR UPDATE';
    }

    $stmt = $pdo->prepare($sql);
    $stmt->execute([$userId]);
    $row = $stmt->fetch();
    if (!$row) {
        return [];
    }

    $today = focuslock_today_key();
    $unlockDayKey = (string) ($row['unlock_day_key'] ?? '');
    if ($unlockDayKey !== $today) {
        $reset = $pdo->prepare('UPDATE user_settings SET unlocks_used_today = 0, unlock_day_key = ? WHERE user_id = ?');
        $reset->execute([$today, $userId]);
        $row['unlocks_used_today'] = 0;
        $row['unlock_day_key'] = $today;
    }

    return $row;
}

function focuslock_lock_state_payload(array $row): array
{
    $now = new DateTimeImmutable('now');
    $cooldownEndAtRaw = $row['cooldown_end_at'] ?? null;
    $cooldownEndAt = null;
    $cooldownActive = false;
    $cooldownRemainingSeconds = 0;

    if (is_string($cooldownEndAtRaw) && trim($cooldownEndAtRaw) !== '') {
        $cooldownEnd = new DateTimeImmutable($cooldownEndAtRaw);
        $cooldownEndAt = $cooldownEnd->format(DateTimeInterface::ATOM);
        if ($cooldownEnd > $now) {
            $cooldownActive = true;
            $cooldownRemainingSeconds = max(0, $cooldownEnd->getTimestamp() - $now->getTimestamp());
        }
    }

    return [
        'todayUnlockCount' => (int) ($row['unlocks_used_today'] ?? 0),
        'unlockDayKey' => (string) ($row['unlock_day_key'] ?? focuslock_today_key()),
        'cooldownEndAt' => $cooldownEndAt,
        'cooldownActive' => $cooldownActive,
        'cooldownRemainingSeconds' => $cooldownRemainingSeconds,
    ];
}

function focuslock_settings_payload(array $row): array
{
    $monitored = json_decode((string) ($row['monitored_apps_json'] ?? '[]'), true);
    if (!is_array($monitored)) {
        $monitored = [];
    }

    return [
        'userName' => '',
        'dailyLimitMinutes' => (int) ($row['daily_limit_minutes'] ?? 60),
        'cooldownMinutes' => (int) ($row['cooldown_minutes'] ?? 30),
        'extraUnlockMinutes' => (int) ($row['extra_unlock_minutes'] ?? 15),
        'maxUnlocksPerDay' => (int) ($row['max_unlocks_per_day'] ?? 1),
        'monitoredApps' => array_values(array_map('strval', $monitored)),
        'lockScheduleEnabled' => (bool) ($row['lock_schedule_enabled'] ?? 0),
        'scheduleStartHour' => (int) ($row['schedule_start_hour'] ?? 8),
        'scheduleStartMinute' => (int) ($row['schedule_start_minute'] ?? 0),
        'scheduleEndHour' => (int) ($row['schedule_end_hour'] ?? 22),
        'scheduleEndMinute' => (int) ($row['schedule_end_minute'] ?? 0),
        'accelerometerEnabled' => (bool) ($row['accelerometer_enabled'] ?? 1),
        'wakeHour' => (int) ($row['wake_hour'] ?? 7),
        'wakeMinute' => (int) ($row['wake_minute'] ?? 0),
        'sleepHour' => (int) ($row['sleep_hour'] ?? 23),
        'sleepMinute' => (int) ($row['sleep_minute'] ?? 0),
        'notificationsEnabled' => (bool) ($row['notifications_enabled'] ?? 1),
    ];
}
