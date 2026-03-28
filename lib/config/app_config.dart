import 'dart:ui';

abstract class AppConfig {
  // Const and final configuration values (immutable)
  static const Color primaryColor = Color(0xFF5625BA);
  static const Color primaryColorLight = Color(0xFFCCBDEA);
  static const Color secondaryColor = Color(0xFF41a2bc);

  static const Color chatColor = primaryColor;
  static const double messageFontSize = 16.0;
  static const bool allowOtherHomeservers = true;
  static const bool enableRegistration = true;
  static const bool hideTypingUsernames = false;

  static const String inviteLinkPrefix = 'https://matrix.to/#/';
  static const String deepLinkPrefix = 'com.letsyak://chat/';
  static const String schemePrefix = 'matrix:';
  static const String pushNotificationsChannelId = 'letsyak_push';
  static const String pushNotificationsAppId = 'com.letsyak.app';
  static const double borderRadius = 16.0;
  static const double spaceBorderRadius = 11.0;
  static const double columnWidth = 360.0;

  static const String enablePushTutorial =
      'https://letsyak.com/help/push-notifications';
  static const String encryptionTutorial =
      'https://letsyak.com/help/encryption';
  static const String startChatTutorial =
      'https://letsyak.com/help/getting-started';
  static const String howDoIGetStickersTutorial =
      'https://letsyak.com/help/stickers';
  static const String appId = 'com.letsyak.LetsYak';
  static const String appOpenUrlScheme = 'letsyak';

  static const String sourceCodeUrl =
      'https://github.com/gazzagart/mayberychat';
  static const String supportUrl =
      'https://github.com/gazzagart/mayberychat/issues';
  static const String changelogUrl = 'https://letsyak.com/changelog';
  static const String donationUrl = '';

  static const Set<String> defaultReactions = {'👍', '❤️', '😂', '😮', '😢'};

  static final Uri newIssueUrl = Uri(
    scheme: 'https',
    host: 'github.com',
    path: '/gazzagart/mayberychat/issues/new',
  );

  static final Uri homeserverList = Uri(
    scheme: 'https',
    host: 'raw.githubusercontent.com',
    path: 'gazzagart/mayberychat/refs/heads/main/recommended_homeservers.json',
  );

  static const String mainIsolatePortName = 'main_isolate';
  static const String pushIsolatePortName = 'push_isolate';
}
