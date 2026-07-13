import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solana/solana.dart';
import '../services/domain_resolver.dart';
import '../services/mwa_service.dart';
import '../util/names.dart';

enum WalletKind { guest, mwa }

/// The player's identity + payout address. Two flavors: a real external wallet connected over
/// Mobile Wallet Adapter (the user's choice, Seed Vault on Seeker), or a silent guest wallet used
/// as a non-crashing fallback where MWA can't run (iOS, or Android with no wallet yet).
abstract class Wallet {
  String get address;
  WalletKind get kind;

  /// The wallet's own account label (Seed Vault gives this on Seeker); null for guest.
  String? get label;

  String get short => '${address.substring(0, 4)}…${address.substring(address.length - 4)}';
  bool get isConnected => kind == WalletKind.mwa;
}

/// A connected external wallet (MWA). Quivo never holds its key. Identity survives app reinstall
/// because the key lives in the user's wallet / Seed Vault, not our storage.
class MwaWallet implements Wallet {
  const MwaWallet(this.address, {this.label});
  @override
  final String address;
  @override
  final String? label;
  @override
  WalletKind get kind => WalletKind.mwa;
  @override
  String get short => '${address.substring(0, 4)}…${address.substring(address.length - 4)}';
  @override
  bool get isConnected => true;
}

/// Silent self-custodial ed25519 keypair, kept in the OS keystore. Fallback only: it does NOT
/// survive an Android reinstall (that's exactly why the product path is MWA). Used on iOS/sim and
/// before the user connects a real wallet, so the app is always usable.
class GuestWallet implements Wallet {
  GuestWallet._(this._seed, this.keyPair, this.address);

  final List<int> _seed;
  final Ed25519HDKeyPair keyPair;
  @override
  final String address;

  @override
  WalletKind get kind => WalletKind.guest;
  @override
  String? get label => null;
  @override
  String get short => '${address.substring(0, 4)}…${address.substring(address.length - 4)}';
  @override
  bool get isConnected => false;

  String get secretB64 => base64Encode(_seed);

  static Future<GuestWallet> loadOrCreate(FlutterSecureStorage storage) async {
    final existing = await storage.read(key: _kGuestSeed);
    if (existing != null) {
      try {
        return await _fromSeed(base64Decode(existing));
      } catch (_) {/* corrupt, mint fresh */}
    }
    final rng = Random.secure();
    final seed = List<int>.generate(32, (_) => rng.nextInt(256));
    await storage.write(key: _kGuestSeed, value: base64Encode(seed));
    return _fromSeed(seed);
  }

  static Future<GuestWallet> _fromSeed(List<int> seed) async {
    final kp = await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: seed);
    return GuestWallet._(seed, kp, kp.publicKey.toBase58());
  }
}

const _kGuestSeed = 'quivo_wallet_seed_b64';
const _kMwaAddress = 'quivo_mwa_address';
const _kMwaToken = 'quivo_mwa_token';
const _kMwaLabel = 'quivo_mwa_label';

const _storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

/// Resolves the ACTIVE wallet: a persisted MWA connection if the user has connected one, else the
/// guest fallback. Awaited once at splash so every screen reads `.address` synchronously after.
final walletProvider = FutureProvider<Wallet>((ref) async {
  final addr = await _storage.read(key: _kMwaAddress);
  if (addr != null && addr.isNotEmpty) {
    return MwaWallet(addr, label: await _storage.read(key: _kMwaLabel));
  }
  return GuestWallet.loadOrCreate(_storage);
});

enum ConnectStatus { idle, connecting, connected, error }

class WalletConnectState {
  const WalletConnectState({this.status = ConnectStatus.idle, this.error});
  final ConnectStatus status;
  final String? error;
}

/// Drives the interactive MWA connect (and disconnect). On success it persists the connection and
/// invalidates [walletProvider] so the whole app re-resolves to the connected wallet.
class WalletConnectController extends Notifier<WalletConnectState> {
  final _mwa = const MwaService();

  @override
  WalletConnectState build() => const WalletConnectState();

  bool get isSupported => _mwa.isSupported;

  Future<MwaConnection?> connect() async {
    state = const WalletConnectState(status: ConnectStatus.connecting);
    try {
      final conn = await _mwa.connect();
      await _storage.write(key: _kMwaAddress, value: conn.address);
      await _storage.write(key: _kMwaToken, value: conn.authToken);
      if (conn.label != null) await _storage.write(key: _kMwaLabel, value: conn.label!);
      ref.invalidate(walletProvider);
      state = const WalletConnectState(status: ConnectStatus.connected);
      return conn;
    } on MwaUnavailable catch (e) {
      state = WalletConnectState(status: ConnectStatus.error, error: e.reason);
      return null;
    }
  }

  Future<void> disconnect() async {
    await _storage.delete(key: _kMwaAddress);
    await _storage.delete(key: _kMwaToken);
    await _storage.delete(key: _kMwaLabel);
    ref.invalidate(walletProvider);
    state = const WalletConnectState();
  }
}

final walletConnectProvider =
    NotifierProvider<WalletConnectController, WalletConnectState>(WalletConnectController.new);

/// The name to pre-fill for the player: a connected wallet's on-chain domain (.skr / .sol / any
/// TLD) if it has one, else the wallet's own Seed Vault label, else an Apple-Arcade-style random
/// suggestion. Only the random fallback is used when nothing real is available, per the rule that
/// a real name (like a .skr) must win over a random one.
final suggestedNameProvider = FutureProvider<String>((ref) async {
  final w = await ref.watch(walletProvider.future);
  if (w.isConnected) {
    final domain = await const DomainResolver().resolveName(w.address);
    if (domain != null && domain.trim().isNotEmpty) return domain.trim();
  }
  final label = w.label;
  if (label != null && label.trim().isNotEmpty) return label.trim();
  return suggestName(w.address);
});
