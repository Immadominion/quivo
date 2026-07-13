import 'package:flutter/foundation.dart';
import 'package:solana/solana.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';
import '../config.dart';

/// Result of a Mobile Wallet Adapter authorize: the connected wallet's identity + the token we
/// keep to re-authorize (or deauthorize) later. On Seeker this is a Seed Vault account.
class MwaConnection {
  const MwaConnection({
    required this.address,
    required this.authToken,
    this.label,
  });
  final String address;
  final String authToken;
  final String? label;
}

/// Thrown when MWA can't run at all: not Android, or no wallet app / Seed Vault present.
class MwaUnavailable implements Exception {
  const MwaUnavailable(this.reason);
  final String reason;
  @override
  String toString() => 'MwaUnavailable: $reason';
}

/// Thin wrapper over solana_mobile_client's association + authorize flow. MWA is Android-only
/// (the protocol is Android-intent based); everywhere else this reports unavailable so callers
/// fall back to a guest wallet. See docs + memory: the user chose MWA-only wallet-connect.
class MwaService {
  const MwaService();

  bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  /// Runs the full local-association authorize handshake and returns the connected identity.
  /// Throws [MwaUnavailable] if MWA can't run or the user dismissed the wallet without authorizing.
  Future<MwaConnection> connect() async {
    if (!isSupported) {
      throw const MwaUnavailable(
        'Wallet connect needs an Android device with a Solana wallet.',
      );
    }
    LocalAssociationScenario? scenario;
    try {
      scenario = await LocalAssociationScenario.create();
      // Hands off to the wallet app / Seed Vault. Resolves when it returns to us.
      scenario.startActivityForResult(null).ignore();
      final client = await scenario.start();
      final result = await client.authorize(
        identityUri: Uri.parse(kIdentityUri),
        iconUri: Uri.parse('favicon.png'),
        identityName: kAppName,
        cluster: kMwaCluster,
      );
      if (result == null) {
        throw const MwaUnavailable(
          'No wallet responded. Is a Solana wallet installed?',
        );
      }
      final address = Ed25519HDPublicKey(result.publicKey).toBase58();
      return MwaConnection(
        address: address,
        authToken: result.authToken,
        label: result.accountLabel,
      );
    } on MwaUnavailable {
      rethrow;
    } catch (e) {
      throw MwaUnavailable('Wallet connect failed: $e');
    } finally {
      await scenario?.close();
    }
  }
}
