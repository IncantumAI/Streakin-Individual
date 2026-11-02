// lib/features/sharing/domain/ncx_container.dart
// Spec §10.1: the share container.
//
//   NCX1 | u16 format_ver | u32 headerLen | header (UTF-8 JSON, cleartext,
//   authenticated as AES-GCM AAD) | u16 wrapLen | wrapped content key (CK) |
//   u32 chunkCount | chunk* | u16 sigLen | Ed25519 signature
//
// Each chunk is [u32 len][AES-256-GCM nonce‖ciphertext‖tag] with
// AAD = header ‖ u32 chunkIndex ‖ u8 isLast, so reordering, dropping or
// truncating chunks fails authentication. The plaintext stream is a small
// archive of named entries (manifest.json, records.ndjson, attachments/<id>).

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:streakin/core/crypto/aes_gcm.dart';
import 'package:streakin/core/errors/app_failure.dart';

/// Brand-neutral magic bytes. MUST NEVER change with an app rename: existing
/// exported files would stop being recognised. Guarded by a test.
const List<int> kNcxMagic = [0x4E, 0x43, 0x58, 0x31]; // "NCX1"

/// File extension placeholder. // TODO(rename): final branded extension (Q1).
const String kNcxExtension = 'ncx';

const int kNcxFormatVersion = 1;
const int kNcxChunkSize = 64 * 1024;

enum NcxScheme { pass, pair, key }

enum NcxScope { full, delta }

/// Cleartext, authenticated header.
class NcxHeader {
  const NcxHeader({
    required this.scheme,
    required this.senderDeviceId,
    required this.senderName,
    required this.createdAt,
    required this.scope,
    this.sinceHlc,
    this.kdf,
    this.recipientFingerprint,
    this.ephemeralPub,
    this.signerPub,
  });

  final NcxScheme scheme;
  final String senderDeviceId;
  final String senderName;
  final String createdAt;
  final NcxScope scope;
  final String? sinceHlc;

  /// Passphrase mode: {ops, mem, p, salt(hex)}.
  final Map<String, dynamic>? kdf;

  /// Pair mode.
  final String? recipientFingerprint;
  final String? ephemeralPub; // hex X25519

  /// Pair / raw-key modes: sender's Ed25519 public key (hex).
  final String? signerPub;

  Map<String, dynamic> toJson() => {
    'scheme': scheme.name,
    'sender': senderDeviceId,
    'senderName': senderName,
    'createdAt': createdAt,
    'scope': scope.name,
    if (sinceHlc != null) 'sinceHlc': sinceHlc,
    if (kdf != null) 'kdf': kdf,
    if (recipientFingerprint != null) 'recipient': recipientFingerprint,
    if (ephemeralPub != null) 'ephPub': ephemeralPub,
    if (signerPub != null) 'signerPub': signerPub,
  };

  factory NcxHeader.fromJson(Map<String, dynamic> j) => NcxHeader(
    scheme: NcxScheme.values.byName(j['scheme'] as String),
    senderDeviceId: j['sender'] as String,
    senderName: j['senderName'] as String? ?? '',
    createdAt: j['createdAt'] as String,
    scope: NcxScope.values.byName(j['scope'] as String),
    sinceHlc: j['sinceHlc'] as String?,
    kdf: (j['kdf'] as Map?)?.cast<String, dynamic>(),
    recipientFingerprint: j['recipient'] as String?,
    ephemeralPub: j['ephPub'] as String?,
    signerPub: j['signerPub'] as String?,
  );
}

/// The unencrypted view of a parsed file: header + wrapped CK + raw sections.
class NcxEnvelope {
  const NcxEnvelope({
    required this.header,
    required this.headerBytes,
    required this.wrappedKey,
    required this.chunks,
    required this.signature,
  });
  final NcxHeader header;
  final Uint8List headerBytes;
  final Uint8List wrappedKey;
  final List<Uint8List> chunks;
  final Uint8List signature;
}

/// Decrypted content.
class NcxPayload {
  const NcxPayload(this.entries);
  final Map<String, Uint8List> entries;

  Uint8List get manifestBytes => entries['manifest.json'] ?? Uint8List(0);
  Map<String, dynamic> get manifest => manifestBytes.isEmpty
      ? const {}
      : jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;
  String get recordsNdjson =>
      utf8.decode(entries['records.ndjson'] ?? Uint8List(0));
}

// ── Archive (named entries) ──────────────────────────────────────────────────

Uint8List packArchive(Map<String, Uint8List> entries) {
  final b = BytesBuilder();
  for (final e in entries.entries) {
    final name = utf8.encode(e.key);
    b.add(_u16(name.length));
    b.add(name);
    b.add(_u32(e.value.length));
    b.add(e.value);
  }
  return b.toBytes();
}

Map<String, Uint8List> unpackArchive(Uint8List data) {
  final out = <String, Uint8List>{};
  final bd = ByteData.sublistView(data);
  var o = 0;
  while (o < data.length) {
    if (o + 2 > data.length) throw const CryptoFailure('Corrupt archive');
    final nameLen = bd.getUint16(o);
    o += 2;
    if (o + nameLen + 4 > data.length) {
      throw const CryptoFailure('Corrupt archive');
    }
    final name = utf8.decode(data.sublist(o, o + nameLen));
    o += nameLen;
    final len = bd.getUint32(o);
    o += 4;
    if (o + len > data.length) throw const CryptoFailure('Corrupt archive');
    out[name] = Uint8List.sublistView(data, o, o + len);
    o += len;
  }
  return out;
}

// ── Chunked AEAD ─────────────────────────────────────────────────────────────

Uint8List _aad(Uint8List header, int index, bool last) {
  final b = BytesBuilder()
    ..add(header)
    ..add(_u32(index))
    ..addByte(last ? 1 : 0);
  return b.toBytes();
}

Future<List<Uint8List>> encryptChunks(
  Uint8List plaintext,
  Uint8List ck,
  Uint8List headerBytes,
) async {
  final n = plaintext.isEmpty
      ? 1
      : (plaintext.length + kNcxChunkSize - 1) ~/ kNcxChunkSize;
  final out = <Uint8List>[];
  for (var i = 0; i < n; i++) {
    final start = i * kNcxChunkSize;
    final end = (start + kNcxChunkSize).clamp(0, plaintext.length);
    out.add(
      await AesGcm256.encrypt(
        Uint8List.sublistView(plaintext, start, end),
        ck,
        aad: _aad(headerBytes, i, i == n - 1),
      ),
    );
  }
  return out;
}

Future<Uint8List> decryptChunks(
  List<Uint8List> chunks,
  Uint8List ck,
  Uint8List headerBytes,
) async {
  if (chunks.isEmpty) throw const CryptoFailure('No payload');
  final b = BytesBuilder();
  for (var i = 0; i < chunks.length; i++) {
    b.add(
      await AesGcm256.decrypt(
        chunks[i],
        ck,
        aad: _aad(headerBytes, i, i == chunks.length - 1),
      ),
    );
  }
  return b.toBytes();
}

/// What the Ed25519 signature covers: header ‖ wrapped CK ‖ SHA-256(manifest).
Uint8List signedMessage(
  Uint8List headerBytes,
  Uint8List wrappedKey,
  Uint8List manifestBytes,
) {
  final b = BytesBuilder()
    ..add(headerBytes)
    ..add(wrappedKey)
    ..add(sha256.convert(manifestBytes).bytes);
  return b.toBytes();
}

// ── Binary helpers ───────────────────────────────────────────────────────────

Uint8List _u16(int v) => Uint8List(2)..buffer.asByteData().setUint16(0, v);
Uint8List _u32(int v) => Uint8List(4)..buffer.asByteData().setUint32(0, v);

/// Serialises an envelope (already encrypted) to bytes.
Uint8List serializeEnvelope(NcxEnvelope e) {
  final b = BytesBuilder()
    ..add(kNcxMagic)
    ..add(_u16(kNcxFormatVersion))
    ..add(_u32(e.headerBytes.length))
    ..add(e.headerBytes)
    ..add(_u16(e.wrappedKey.length))
    ..add(e.wrappedKey)
    ..add(_u32(e.chunks.length));
  for (final c in e.chunks) {
    b
      ..add(_u32(c.length))
      ..add(c);
  }
  b
    ..add(_u16(e.signature.length))
    ..add(e.signature);
  return b.toBytes();
}

/// Parses bytes into an envelope without decrypting. Throws [CryptoFailure]
/// for anything that is not a well-formed container.
NcxEnvelope parseEnvelope(Uint8List data) {
  const bad = CryptoFailure('Not a valid share file');
  if (data.length < 4 + 2 + 4) throw bad;
  for (var i = 0; i < 4; i++) {
    if (data[i] != kNcxMagic[i]) throw bad;
  }
  final bd = ByteData.sublistView(data);
  var o = 4;
  final ver = bd.getUint16(o);
  o += 2;
  if (ver != kNcxFormatVersion) {
    throw const CryptoFailure('Unsupported share file version');
  }
  Uint8List take(int n) {
    if (n < 0 || o + n > data.length) throw bad;
    final s = Uint8List.sublistView(data, o, o + n);
    o += n;
    return s;
  }

  final headerLen = bd.getUint32(o);
  o += 4;
  final headerBytes = Uint8List.fromList(take(headerLen));
  final wrapLen = _readU16(bd, o, data.length);
  o += 2;
  final wrapped = Uint8List.fromList(take(wrapLen));
  if (o + 4 > data.length) throw bad;
  final count = bd.getUint32(o);
  o += 4;
  if (count == 0 || count > 1 << 20) throw bad;
  final chunks = <Uint8List>[];
  for (var i = 0; i < count; i++) {
    if (o + 4 > data.length) throw bad;
    final len = bd.getUint32(o);
    o += 4;
    chunks.add(Uint8List.fromList(take(len)));
  }
  final sigLen = _readU16(bd, o, data.length);
  o += 2;
  final sig = Uint8List.fromList(take(sigLen));

  final NcxHeader header;
  try {
    header = NcxHeader.fromJson(
      jsonDecode(utf8.decode(headerBytes)) as Map<String, dynamic>,
    );
  } catch (_) {
    throw bad;
  }
  return NcxEnvelope(
    header: header,
    headerBytes: headerBytes,
    wrappedKey: wrapped,
    chunks: chunks,
    signature: sig,
  );
}

int _readU16(ByteData bd, int o, int len) {
  if (o + 2 > len) throw const CryptoFailure('Not a valid share file');
  return bd.getUint16(o);
}
