class WorkspaceConfig {
  final String id;
  final String slug;
  final String displayName;
  final String homeserverUrl;
  final String vaultApiUrl;
  final String isolationTier;
  final String securityMode;
  final List<String> loginMethods;
  final WorkspaceBranding branding;
  final Map<String, bool> features;

  const WorkspaceConfig({
    required this.id,
    required this.slug,
    required this.displayName,
    required this.homeserverUrl,
    required this.vaultApiUrl,
    required this.isolationTier,
    required this.securityMode,
    required this.loginMethods,
    required this.branding,
    required this.features,
  });

  bool get isDedicated => isolationTier == WorkspaceIsolationTier.dedicated;

  bool get isShared => isolationTier == WorkspaceIsolationTier.shared;

  bool get isSimpleSecurity => securityMode == WorkspaceSecurityMode.simple;

  bool get isEasyE2ee => securityMode == WorkspaceSecurityMode.easyE2ee;

  bool get isBalancedSecurity => securityMode == WorkspaceSecurityMode.balanced;

  bool get isStrictSecurity => securityMode == WorkspaceSecurityMode.strict;

  bool get shouldForceBackupAfterLogin => isStrictSecurity;

  bool get supportsPasswordLogin => loginMethods.contains('password');

  bool get supportsSsoLogin => loginMethods.contains('sso');

  bool get hasVault => features['vault'] ?? false;

  factory WorkspaceConfig.fromJson(Map<String, dynamic> json) {
    return WorkspaceConfig(
      id: json['id'] as String,
      slug: json['slug'] as String,
      displayName: json['display_name'] as String,
      homeserverUrl: json['homeserver_url'] as String,
      vaultApiUrl: json['vault_api_url'] as String,
      isolationTier:
          json['isolation_tier'] as String? ?? WorkspaceIsolationTier.dedicated,
      securityMode:
          json['security_mode'] as String? ?? WorkspaceSecurityMode.easyE2ee,
      loginMethods: (json['login_methods'] as List? ?? const ['password'])
          .map((method) => method.toString())
          .toList(),
      branding: WorkspaceBranding.fromJson(
        json['branding'] as Map<String, dynamic>? ?? const {},
      ),
      features: (json['features'] as Map<String, dynamic>? ?? const {}).map(
        (key, value) => MapEntry(key, value == true),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'display_name': displayName,
    'homeserver_url': homeserverUrl,
    'vault_api_url': vaultApiUrl,
    'isolation_tier': isolationTier,
    'security_mode': securityMode,
    'login_methods': loginMethods,
    'branding': branding.toJson(),
    'features': features,
  };
}

class WorkspaceBranding {
  final String? logoUrl;
  final String? primaryColor;
  final String? secondaryColor;
  final String? supportUrl;
  final String? privacyUrl;

  const WorkspaceBranding({
    this.logoUrl,
    this.primaryColor,
    this.secondaryColor,
    this.supportUrl,
    this.privacyUrl,
  });

  factory WorkspaceBranding.fromJson(Map<String, dynamic> json) {
    return WorkspaceBranding(
      logoUrl: _blankToNull(json['logo_url'] as String?),
      primaryColor: _blankToNull(json['primary_color'] as String?),
      secondaryColor: _blankToNull(json['secondary_color'] as String?),
      supportUrl: _blankToNull(json['support_url'] as String?),
      privacyUrl: _blankToNull(json['privacy_url'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    'logo_url': logoUrl,
    'primary_color': primaryColor,
    'secondary_color': secondaryColor,
    'support_url': supportUrl,
    'privacy_url': privacyUrl,
  };
}

abstract class WorkspaceIsolationTier {
  static const shared = 'shared';
  static const dedicated = 'dedicated';
}

abstract class WorkspaceSecurityMode {
  static const simple = 'simple';
  static const easyE2ee = 'easy_e2ee';
  static const balanced = 'balanced';
  static const strict = 'strict';
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
