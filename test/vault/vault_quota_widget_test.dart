import 'package:fluffychat/pages/vault/vault_quota_widget.dart';
import 'package:fluffychat/utils/vault/vault_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('quota widget shows plan, remaining space, and upgrade hint', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VaultQuotaWidget(
            quota: VaultQuota(
              usedBytes: 200000000,
              totalBytes: 524288000,
              tier: 'free',
              tierLabel: 'Free',
              limitLabel: '500 MB',
              remainingBytes: 324288000,
              upgradeAvailable: true,
              upgradeTier: 'plus',
              upgradeTierLabel: 'Plus',
              upgradeLimitBytes: 5368709120,
              upgradeLimitLabel: '5 GB',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Free plan'), findsOneWidget);
    expect(find.text('200.0 MB of 500 MB used'), findsOneWidget);
    expect(find.text('Plus includes 5 GB'), findsOneWidget);
  });

  testWidgets('quota widget shows full state without upgrade hint for Plus', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VaultQuotaWidget(
            quota: VaultQuota(
              usedBytes: 5368709121,
              totalBytes: 5368709120,
              tier: 'plus',
              tierLabel: 'Plus',
              limitLabel: '5 GB',
              remainingBytes: 0,
              isOverQuota: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Plus plan'), findsOneWidget);
    expect(find.text('Storage full'), findsOneWidget);
    expect(find.text('Plus includes 5 GB'), findsNothing);
  });
}
