import 'package:fluffychat/pages/vault/vault_preview_page.dart';
import 'package:fluffychat/utils/vault/vault_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('vaultPreviewTypeFor', () {
    test('detects previewable raster images', () {
      expect(
        vaultPreviewTypeFor(_file(name: 'holiday.jpg', mimeType: 'image/jpeg')),
        VaultPreviewType.image,
      );
      expect(
        vaultPreviewTypeFor(_file(name: 'scan.png')),
        VaultPreviewType.image,
      );
    });

    test('does not route svg through Image.network preview', () {
      expect(
        vaultPreviewTypeFor(
          _file(name: 'diagram.svg', mimeType: 'image/svg+xml'),
        ),
        VaultPreviewType.download,
      );
    });

    test('detects previewable videos', () {
      expect(
        vaultPreviewTypeFor(_file(name: 'clip.mp4', mimeType: 'video/mp4')),
        VaultPreviewType.video,
      );
      expect(
        vaultPreviewTypeFor(_file(name: 'screen.webm')),
        VaultPreviewType.video,
      );
    });

    test('detects previewable PDFs', () {
      expect(
        vaultPreviewTypeFor(
          _file(name: 'contract.pdf', mimeType: 'application/pdf'),
        ),
        VaultPreviewType.pdf,
      );
      expect(
        vaultPreviewTypeFor(_file(name: 'statement.pdf')),
        VaultPreviewType.pdf,
      );
    });

    test('keeps folders and unsupported files on the download flow', () {
      expect(
        vaultPreviewTypeFor(_file(name: 'Docs', isFolder: true)),
        VaultPreviewType.download,
      );
      expect(
        vaultPreviewTypeFor(
          _file(name: 'archive.zip', mimeType: 'application/zip'),
        ),
        VaultPreviewType.download,
      );
    });
  });

  testWidgets('preview page shows retry state when download URL fails', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VaultPreviewPage(
          file: _file(name: 'holiday.jpg', mimeType: 'image/jpeg'),
          loadDownloadUrl: (_) async {
            attempts++;
            throw Exception('boom');
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump();

    expect(find.text('Preview could not be loaded.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(attempts, 1);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump();

    expect(attempts, 2);
  });

  testWidgets('preview page routes PDFs to the PDF preview builder', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VaultPreviewPage(
          file: _file(name: 'contract.pdf', mimeType: 'application/pdf'),
          loadDownloadUrl: (_) async => 'https://vault.example/contract.pdf',
          pdfPreviewBuilder: (context, downloadUrl) => Text(
            'PDF preview for $downloadUrl',
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump();

    expect(
      find.text('PDF preview for https://vault.example/contract.pdf'),
      findsOneWidget,
    );
  });
}

VaultFile _file({
  required String name,
  String? mimeType,
  bool isFolder = false,
}) => VaultFile(
  name: name,
  path: isFolder ? '/$name/' : '/$name',
  size: 1024,
  mimeType: mimeType,
  lastModified: DateTime.utc(2026, 4, 25),
  isFolder: isFolder,
);
