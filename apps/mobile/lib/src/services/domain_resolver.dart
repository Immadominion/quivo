import 'package:solana/solana.dart';
import 'package:tld_parser/tld_parser.dart';
import '../config.dart';

/// Reverse-resolves a connected wallet address to its on-chain display name (AllDomains ANS:
/// `.skr` on Seeker, `.sol`, or any TLD). This is what makes a Seeker user's `.skr` name show up
/// in Quivo instead of a random suggestion. Best-effort: any failure returns null so onboarding
/// never blocks on the network.
class DomainResolver {
  const DomainResolver();

  Future<String?> resolveName(String address) =>
      _resolve(address).timeout(const Duration(seconds: 6), onTimeout: () => null);

  Future<String?> _resolve(String address) async {
    try {
      final rpc = RpcClient(kDomainRpc);
      final parser = TldParser(rpc);
      final owner = Ed25519HDPublicKey.fromBase58(address);

      // 1. The user's chosen MAIN domain across all TLDs (a single account read; works on public
      //    RPC). This respects whatever they set as their primary identity, .skr or otherwise.
      final main = await parser.tryGetMainDomain(owner);
      if (main != null) {
        final name = '${main.domain}.${main.tld}';
        return name.isNotEmpty && name != '.' ? name : null;
      }

      // 2. No main set: if they own any `.skr`, use the first one (Seeker identity).
      final skr = await parser.getParsedAllUserDomainsFromTld(owner, 'skr');
      if (skr.isNotEmpty) return skr.first.domain; // already the full 'name.skr'

      return null;
    } catch (_) {
      return null;
    }
  }
}
