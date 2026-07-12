import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solana/solana.dart';

/// The player's self-custodial **ephemeral wallet** - an ed25519 keypair minted silently on first
/// run and kept in the OS keychain/keystore. It's just an identity + payout address: for Tier-1 the
/// relayer signs and sponsors gas, so the phone never signs a transaction and never shows a seed
/// phrase. (Reconstruction mirrors throtl's `Ed25519HDKeyPair.fromPrivateKeyBytes`.)
class QuivoWallet {
  QuivoWallet._(this._seed, this.keyPair, this.address);

  final List<int> _seed;
  final Ed25519HDKeyPair keyPair;
  final String address;

  static const _key = 'quivo_wallet_seed_b64';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String get short => '${address.substring(0, 4)}…${address.substring(address.length - 4)}';

  /// The 32-byte secret, base64 - for the "export key" advanced flow only.
  String get secretB64 => base64Encode(_seed);

  /// Load the persisted wallet, or mint + persist a fresh one on first run.
  static Future<QuivoWallet> loadOrCreate() async {
    final existing = await _storage.read(key: _key);
    if (existing != null) {
      try {
        return await _fromSeed(base64Decode(existing));
      } catch (_) {
        // fall through to mint a new one if the stored blob is corrupt
      }
    }
    final rng = Random.secure();
    final seed = List<int>.generate(32, (_) => rng.nextInt(256));
    await _storage.write(key: _key, value: base64Encode(seed));
    return _fromSeed(seed);
  }

  static Future<QuivoWallet> _fromSeed(List<int> seed) async {
    final kp = await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: seed);
    return QuivoWallet._(seed, kp, kp.publicKey.toBase58());
  }
}

/// Async wallet provider - the app awaits this once at startup (splash) so every screen has the
/// address synchronously afterwards.
final walletProvider = FutureProvider<QuivoWallet>((ref) => QuivoWallet.loadOrCreate());
