class SocialApp {
  final String packageName;
  final String displayName;
  final String emoji;

  const SocialApp({
    required this.packageName,
    required this.displayName,
    required this.emoji,
  });
}

class SocialApps {
  SocialApps._();

  static const List<SocialApp> all = [
    SocialApp(packageName: 'com.instagram.android', displayName: 'Instagram', emoji: '📸'),
    SocialApp(packageName: 'com.zhiliaoapp.musically', displayName: 'TikTok', emoji: '🎵'),
    SocialApp(packageName: 'com.twitter.android', displayName: 'X (Twitter)', emoji: '🐦'),
    SocialApp(packageName: 'com.facebook.katana', displayName: 'Facebook', emoji: '👥'),
    SocialApp(packageName: 'com.snapchat.android', displayName: 'Snapchat', emoji: '👻'),
    SocialApp(packageName: 'com.whatsapp', displayName: 'WhatsApp', emoji: '💬'),
    SocialApp(packageName: 'com.google.android.youtube', displayName: 'YouTube', emoji: '▶️'),
    SocialApp(packageName: 'com.linkedin.android', displayName: 'LinkedIn', emoji: '💼'),
    SocialApp(packageName: 'com.pinterest', displayName: 'Pinterest', emoji: '📌'),
    SocialApp(packageName: 'com.reddit.frontpage', displayName: 'Reddit', emoji: '🤖'),
    SocialApp(packageName: 'com.tumblr', displayName: 'Tumblr', emoji: '✏️'),
    SocialApp(packageName: 'com.discord', displayName: 'Discord', emoji: '🎮'),
    SocialApp(packageName: 'com.bereal.mobile', displayName: 'BeReal', emoji: '📷'),
    SocialApp(packageName: 'com.threads.android', displayName: 'Threads', emoji: '🧵'),
    SocialApp(packageName: 'tv.twitch.android.app', displayName: 'Twitch', emoji: '🎲'),
  ];

  static SocialApp? fromPackage(String packageName) {
    try {
      return all.firstWhere((a) => a.packageName == packageName);
    } catch (_) {
      return null;
    }
  }
}
