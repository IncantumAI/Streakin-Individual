// lib/features/sharing/presentation/sharing_settings_screen.dart
// Spec §4.10/§10: paired devices, export, import (preview → apply), raw key.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:streakin/core/crypto/base32.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/errors/app_failure.dart';
import 'package:streakin/core/security/password_strength.dart';
import 'package:streakin/core/storage/app_database.dart' show SyncPeer;
import 'package:streakin/features/sharing/application/sharing_providers.dart';
import 'package:streakin/features/sharing/data/device_identity.dart';
import 'package:streakin/features/sharing/data/ncx_reader.dart'
    show kTamperedMessage;
import 'package:streakin/features/sharing/domain/ncx_container.dart';

class SharingSettingsScreen extends ConsumerWidget {
  const SharingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final peers = ref.watch(syncPeersProvider).value ?? const <SyncPeer>[];
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: const Text('Export, import & devices'),
        backgroundColor: colors.surface,
      ),
      body: ListView(
        children: [
          _h('Paired devices', colors),
          if (peers.isEmpty)
            const ListTile(
              title: Text('No paired devices'),
              subtitle: Text(
                'Pair a device to export directly to it and '
                'send only what changed.',
              ),
            ),
          for (final d in peers)
            ListTile(
              leading: Icon(AppIcons.devices, color: colors.brand),
              title: Text(d.name),
              subtitle: Text(
                'Paired ${_ago(d.pairedAt)} · last sent ${d.lastSentHlc == null ? 'never' : 'recorded'}',
              ),
              trailing: IconButton(
                icon: const Icon(AppIcons.linkOff),
                tooltip: 'Unpair',
                onPressed: () async {
                  await ref.read(syncPeerStoreProvider)?.unpair(d.deviceId);
                },
              ),
            ),
          ListTile(
            leading: Icon(AppIcons.addLink, color: colors.brand),
            title: const Text('Pair a device'),
            onTap: () => _pair(context, ref),
          ),
          const Divider(height: 1),
          _h('Export', colors),
          ListTile(
            leading: Icon(AppIcons.export_, color: colors.brand),
            title: const Text('Export data'),
            subtitle: const Text('Passphrase, paired device or raw key'),
            onTap: () => _export(context, ref, peers),
          ),
          _h('Import', colors),
          ListTile(
            leading: Icon(AppIcons.import_, color: colors.brand),
            title: const Text('Import data'),
            subtitle: const Text('Choose a .$kNcxExtension file'),
            onTap: () => _import(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(AppIcons.storageOutlined, color: colors.brand),
            title: const Text('Storage usage & caches'),
            trailing: const Icon(AppIcons.chevronRight),
            onTap: () => context.push('/settings/data'),
          ),
        ],
      ),
    );
  }

  Widget _h(String t, AppColorTokens c) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      t.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: c.textMuted,
      ),
    ),
  );

  static String _ago(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final days = DateTime.now().difference(d).inDays;
    return days <= 0 ? 'today' : '$days d ago';
  }

  // ── Pairing (Mode B) ──────────────────────────────────────────────────────

  Future<void> _pair(BuildContext context, WidgetRef ref) async {
    final identity = await ref.read(deviceIdentityProvider.future);
    final store = ref.read(syncPeerStoreProvider);
    if (store == null || !context.mounted) return;
    final theirs = TextEditingController();
    final name = TextEditingController(text: 'My other device');
    String? sas;
    DevicePublicBundle? bundle;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Pair a device'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('1. Show this on the other device:'),
                const SizedBox(height: 8),
                Center(
                  child: QrImageView(
                    data: identity.public.base32,
                    size: 160,
                    backgroundColor: Colors.white,
                  ),
                ),
                SelectableText(
                  Base32.grouped(identity.public.base32, size: 8),
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 12),
                const Text('2. Paste the other device\'s code:'),
                TextField(
                  controller: theirs,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Their code'),
                ),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Name this device',
                  ),
                ),
                if (sas != null) ...[
                  const SizedBox(height: 12),
                  const Text('3. Both devices must show the same number:'),
                  Center(
                    child: Text(
                      sas!,
                      style: const TextStyle(
                        fontSize: 32,
                        letterSpacing: 6,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (error != null)
                  Text(error!, style: TextStyle(color: ctx.colors.danger)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            if (sas == null)
              FilledButton(
                onPressed: () async {
                  try {
                    final b = DevicePublicBundle.parse(theirs.text);
                    final secret = await identity.sharedSecret(b.x25519);
                    setState(() {
                      bundle = b;
                      sas = DeviceIdentity.sasFor(secret);
                      error = null;
                    });
                  } catch (_) {
                    setState(() => error = 'That code is not valid.');
                  }
                },
                child: const Text('Show check number'),
              )
            else
              FilledButton(
                onPressed: () async {
                  await store.add(
                    bundle!,
                    name.text.trim().isEmpty ? 'Device' : name.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Numbers match — confirm'),
              ),
          ],
        ),
      ),
    );
    theirs.dispose();
    name.dispose();
  }

  // ── Export ────────────────────────────────────────────────────────────────

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    List<SyncPeer> peers,
  ) async {
    final service = await ref.read(exportServiceProvider.future);
    if (service == null || !context.mounted) return;

    var scheme = NcxScheme.pass;
    var scope = NcxScope.full;
    SyncPeer? peer = peers.isEmpty ? null : peers.first;
    final pass = TextEditingController();
    final pass2 = TextEditingController();
    final locked = await service.lockedVaultsWithNotes();
    if (!context.mounted) return;

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Export data'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButton<NcxScheme>(
                  value: scheme,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: NcxScheme.pass,
                      child: Text('Passphrase'),
                    ),
                    if (peers.isNotEmpty)
                      const DropdownMenuItem(
                        value: NcxScheme.pair,
                        child: Text('Paired device'),
                      ),
                    const DropdownMenuItem(
                      value: NcxScheme.key,
                      child: Text('Raw key'),
                    ),
                  ],
                  onChanged: (v) => setState(() => scheme = v!),
                ),
                if (scheme == NcxScheme.pass) ...[
                  TextField(
                    controller: pass,
                    obscureText: true,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Passphrase'),
                  ),
                  TextField(
                    controller: pass2,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm passphrase',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pass.text.length < 8
                        ? 'At least 8 characters'
                        : PasswordStrength.estimate(pass.text).label,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                if (scheme == NcxScheme.pair) ...[
                  DropdownButton<SyncPeer>(
                    value: peer,
                    isExpanded: true,
                    items: [
                      for (final d in peers)
                        DropdownMenuItem(value: d, child: Text(d.name)),
                    ],
                    onChanged: (v) => setState(() => peer = v),
                  ),
                  SegmentedButton<NcxScope>(
                    segments: const [
                      ButtonSegment(value: NcxScope.full, label: Text('Full')),
                      ButtonSegment(
                        value: NcxScope.delta,
                        label: Text('Changes only'),
                      ),
                    ],
                    selected: {scope},
                    onSelectionChanged: (s) => setState(() => scope = s.first),
                  ),
                ],
                if (scheme == NcxScheme.key)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'A random key is generated and shown once after export.',
                    ),
                  ),
                if (locked.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Some vaults are locked, so their notes will NOT be exported. '
                      'Unlock them first if you want them included.',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (scheme == NcxScheme.pass &&
                    (pass.text.length < 8 || pass.text != pass2.text)) {
                  return;
                }
                if (scheme == NcxScheme.pair && peer == null) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Export'),
            ),
          ],
        ),
      ),
    );
    final passphrase = pass.text;
    pass.dispose();
    pass2.dispose();
    if (go != true || !context.mounted) return;

    final progress = ValueNotifier<double>(0);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Exporting…'),
          content: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (_, v, _) => LinearProgressIndicator(value: v),
          ),
        ),
      ),
    );
    try {
      final result = await service.export(
        scheme: scheme,
        scope: scope,
        passphrase: scheme == NcxScheme.pass ? passphrase : null,
        peer: scheme == NcxScheme.pair ? peer : null,
        onProgress: (v) => progress.value = v,
      );
      if (context.mounted) Navigator.of(context).pop(); // progress
      if (!context.mounted) return;
      await _deliver(context, result.fileName, result.bytes);
      if (result.rawKey != null && context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Raw key — save it now'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(
                  data: Base32.encode(result.rawKey!),
                  size: 160,
                  backgroundColor: Colors.white,
                ),
                SelectableText(Base32.grouped(Base32.encode(result.rawKey!))),
                const SizedBox(height: 8),
                const Text(
                  'Shown once. The file cannot be opened without it.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _deliver(
    BuildContext context,
    String fileName,
    Uint8List bytes,
  ) async {
    if (Platform.isAndroid) {
      final dir = await getTemporaryDirectory();
      final f = File(p.join(dir.path, fileName));
      await f.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
      return;
    }
    final path = await FilePicker.platform.saveFile(
      fileName: fileName,
      bytes: bytes,
    );
    if (path != null && (Platform.isWindows || Platform.isLinux)) {
      await File(path).writeAsBytes(bytes, flush: true);
    }
  }

  // ── Import ────────────────────────────────────────────────────────────────

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final service = await ref.read(importServiceProvider.future);
    if (service == null) return;
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final bytes =
        picked?.files.single.bytes ??
        (picked?.files.single.path == null
            ? null
            : await File(picked!.files.single.path!).readAsBytes());
    if (bytes == null || !context.mounted) return;

    try {
      final header = service.peek(bytes);
      String? passphrase;
      Uint8List? rawKey;
      if (header.scheme == NcxScheme.pass) {
        final c = TextEditingController();
        passphrase = await _ask(context, 'Passphrase', c, obscure: true);
        c.dispose();
        if (passphrase == null) return;
      } else if (header.scheme == NcxScheme.key) {
        final c = TextEditingController();
        final txt = await _ask(context, 'Raw key', c);
        c.dispose();
        if (txt == null) return;
        rawKey = Base32.decode(txt);
      }
      final session = await service.open(
        bytes,
        passphrase: passphrase,
        rawKey: rawKey,
      );
      final preview = await service.preview(session);
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import preview'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New: ${preview.newCount}'),
              Text('Updated: ${preview.updatedCount}'),
              Text('Conflicts (kept as copies): ${preview.conflictCount}'),
              Text('Deleted: ${preview.deletedCount}'),
              Text('Attachments: ${_mb(preview.attachmentSizeBytes)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await service.apply(session);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Import complete')));
      }
    } on CryptoFailure catch (e) {
      if (context.mounted) {
        _error(context, e.message.isEmpty ? kTamperedMessage : e.message);
      }
    } on ValidationFailure catch (e) {
      if (context.mounted) _error(context, 'Import refused: ${e.message}');
    } catch (_) {
      if (context.mounted) _error(context, kTamperedMessage);
    }
  }

  void _error(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static String _mb(int b) => '${(b / 1024 / 1024).toStringAsFixed(1)} MB';

  Future<String?> _ask(
    BuildContext context,
    String label,
    TextEditingController c, {
    bool obscure = false,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: c,
          obscureText: obscure,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
