// lib/features/sharing/data/device_identity.dart
// Spec §10.2 (Mode B): each device owns an X25519 key pair (key agreement)
// and an Ed25519 key pair (signing), both derived from one random 32-byte
// seed kept in secure storage. The *public bundle* (x25519‖ed25519, 64 bytes)
// is what gets shown as a QR / Base32 string and stored in `sync_peers`.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import 'package:streakin/core/crypto/base32.dart';
import 'package:streakin/core/crypto/hkdf.dart';
import 'package:streakin/core/crypto/secure_bytes.dart';
import 'package:streakin/core/security/brute_force_guard.dart'
    show KeyValueStore, SecureKeyValueStore;
import 'package:streakin/core/storage/identifiers.dart';

/// Public half of a device identity.
class DevicePublicBundle {
  const DevicePublicBundle(this.x25519, this.ed25519);
  final Uint8List x25519;
  final Uint8List ed25519;

  factory DevicePublicBundle.fromBytes(Uint8List b) {
    if (b.length != 64) {
      throw const FormatException('Public key must be 64 bytes');
    }
    return DevicePublicBundle(
      Uint8List.fromList(b.sublist(0, 32)),
      Uint8List.fromList(b.sublist(32)),
    );
  }

  /// Parses the Base32 (dashes/spaces allowed) form.
  factory DevicePublicBundle.parse(String base32) =>
      DevicePublicBundle.fromBytes(Base32.decode(base32));

  Uint8List get bytes => Uint8List.fromList([...x25519, ...ed25519]);
  String get base32 => Base32.encode(bytes);

  /// Short stable id: first 8 bytes of SHA-256(bundle), hex.
  String get fingerprint => SecureBytes.toHex(
    Uint8List.fromList(sha256.convert(bytes).bytes.sublist(0, 8)),
  );
}

class DeviceIdentity {
  DeviceIdentity._(this._x, this._ed, this.public);

  final SimpleKeyPair _x;
  final SimpleKeyPair _ed;
  final DevicePublicBundle public;

  String get deviceId => public.fingerprint;

  static const _x25519 = DartX25519();
  static final _ed25519 = DartEd25519();

  /// Deterministically derives an identity from a 32-byte [seed].
  static Future<DeviceIdentity> fromSeed(Uint8List seed) async {
    final x = await _x25519.newKeyPairFromSeed(
      HkdfDerive.deriveSync(seed, 'ncx-x25519'),
    );
    final ed = await _ed25519.newKeyPairFromSeed(
      HkdfDerive.deriveSync(seed, 'ncx-ed25519'),
    );
    final xp = await x.extractPublicKey();
    final ep = await ed.extractPublicKey();
    return DeviceIdentity._(
      x,
      ed,
      DevicePublicBundle(
        Uint8List.fromList(xp.bytes),
        Uint8List.fromList(ep.bytes),
      ),
    );
  }

  /// Loads the identity from secure storage, creating it on first use.
  static Future<DeviceIdentity> loadOrCreate([
    KeyValueStore store = const SecureKeyValueStore(),
  ]) async {
    var raw = await store.read(AppIdentifiers.ssKeyDevicePrivateKey);
    if (raw == null) {
      raw = base64.encode(SecureBytes.randomBytes(32));
      await store.write(AppIdentifiers.ssKeyDevicePrivateKey, raw);
    }
    return fromSeed(Uint8List.fromList(base64.decode(raw)));
  }

  /// X25519 shared secret with [remoteX25519Public].
  Future<Uint8List> sharedSecret(Uint8List remoteX25519Public) async {
    final k = await _x25519.sharedSecretKey(
      keyPair: _x,
      remotePublicKey: SimplePublicKey(
        remoteX25519Public,
        type: KeyPairType.x25519,
      ),
    );
    return Uint8List.fromList(await k.extractBytes());
  }

  Future<Uint8List> sign(Uint8List message) async {
    final sig = await _ed25519.sign(message, keyPair: _ed);
    return Uint8List.fromList(sig.bytes);
  }

  static Future<bool> verify(
    Uint8List message,
    Uint8List signature,
    Uint8List ed25519Public,
  ) {
    return _ed25519.verify(
      message,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(ed25519Public, type: KeyPairType.ed25519),
      ),
    );
  }

  /// 6-digit Short Authentication String for MITM protection during pairing.
  /// Both devices derive the same value from the shared secret.
  static String sasFor(Uint8List sharedSecret) {
    final okm = HkdfDerive.deriveSync(sharedSecret, 'sas');
    final n = ByteData.sublistView(okm).getUint32(0) % 1000000;
    return n.toString().padLeft(6, '0');
  }
}

/// Ephemeral X25519 pair used by the *sender* in pair mode so that every
/// export has a fresh content-key derivation.
class EphemeralKeys {
  EphemeralKeys._(this._pair, this.publicBytes);
  final SimpleKeyPair _pair;
  final Uint8List publicBytes;

  static Future<EphemeralKeys> generate() async {
    final p = await DeviceIdentity._x25519.newKeyPair();
    final pub = await p.extractPublicKey();
    return EphemeralKeys._(p, Uint8List.fromList(pub.bytes));
  }

  Future<Uint8List> sharedWith(Uint8List remoteX25519Public) async {
    final k = await DeviceIdentity._x25519.sharedSecretKey(
      keyPair: _pair,
      remotePublicKey: SimplePublicKey(
        remoteX25519Public,
        type: KeyPairType.x25519,
      ),
    );
    return Uint8List.fromList(await k.extractBytes());
  }
}
