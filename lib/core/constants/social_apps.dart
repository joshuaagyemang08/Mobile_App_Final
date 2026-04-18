import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SocialApp {
  final String packageName;
  final String displayName;
  final String badge;
  final IconData icon;

  const SocialApp({
    required this.packageName,
    required this.displayName,
    required this.badge,
    required this.icon,
  });
}

class SocialApps {
  SocialApps._();

  static const List<SocialApp> all = [
    SocialApp(packageName: 'com.instagram.android', displayName: 'Instagram', badge: 'IG', icon: FontAwesomeIcons.instagram),
    SocialApp(packageName: 'com.zhiliaoapp.musically', displayName: 'TikTok', badge: 'TT', icon: FontAwesomeIcons.tiktok),
    SocialApp(packageName: 'com.twitter.android', displayName: 'X (Twitter)', badge: 'X', icon: FontAwesomeIcons.xTwitter),
    SocialApp(packageName: 'com.facebook.katana', displayName: 'Facebook', badge: 'FB', icon: FontAwesomeIcons.facebookF),
    SocialApp(packageName: 'com.snapchat.android', displayName: 'Snapchat', badge: 'SC', icon: FontAwesomeIcons.snapchat),
    SocialApp(packageName: 'com.whatsapp', displayName: 'WhatsApp', badge: 'WA', icon: FontAwesomeIcons.whatsapp),
    SocialApp(packageName: 'com.google.android.youtube', displayName: 'YouTube', badge: 'YT', icon: FontAwesomeIcons.youtube),
    SocialApp(packageName: 'com.linkedin.android', displayName: 'LinkedIn', badge: 'IN', icon: FontAwesomeIcons.linkedinIn),
    SocialApp(packageName: 'com.pinterest', displayName: 'Pinterest', badge: 'PT', icon: FontAwesomeIcons.pinterestP),
    SocialApp(packageName: 'com.reddit.frontpage', displayName: 'Reddit', badge: 'RD', icon: FontAwesomeIcons.redditAlien),
    SocialApp(packageName: 'com.tumblr', displayName: 'Tumblr', badge: 'TB', icon: FontAwesomeIcons.tumblr),
    SocialApp(packageName: 'com.discord', displayName: 'Discord', badge: 'DC', icon: FontAwesomeIcons.discord),
    SocialApp(packageName: 'com.bereal.mobile', displayName: 'BeReal', badge: 'BR', icon: Icons.photo_camera_outlined),
    SocialApp(packageName: 'com.threads.android', displayName: 'Threads', badge: 'TH', icon: Icons.alternate_email_rounded),
    SocialApp(packageName: 'tv.twitch.android.app', displayName: 'Twitch', badge: 'TW', icon: FontAwesomeIcons.twitch),
  ];

  static SocialApp? fromPackage(String packageName) {
    try {
      return all.firstWhere((a) => a.packageName == packageName);
    } catch (_) {
      return null;
    }
  }
}
