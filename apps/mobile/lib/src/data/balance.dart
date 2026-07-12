import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solana/solana.dart';
import '../config.dart';
import 'wallet.dart';

/// Live devnet SOL balance for the in-app wallet. autoDispose + refreshable so the Wallet tab can
/// pull-to-refresh. USDC prize balance needs the SPL mint + token account; shown from history for now.
class WalletBalance {
  const WalletBalance({required this.sol});
  final double sol;
}

final balanceProvider = FutureProvider.autoDispose<WalletBalance>((ref) async {
  final wallet = await ref.watch(walletProvider.future);
  final rpc = RpcClient(kRpc);
  final lamports = await rpc.getBalance(wallet.address).then((r) => r.value);
  return WalletBalance(sol: lamports / lamportsPerSol);
});
