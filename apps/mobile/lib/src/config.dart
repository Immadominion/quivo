/// Runtime config. Public builds use the hosted native JSON gateway. Override for local dev with:
///   `flutter run --dart-define=QUIVO_GATEWAY=ws://YOUR-MAC-LAN-IP:2568`
const String kGateway = String.fromEnvironment(
  'QUIVO_GATEWAY',
  defaultValue: 'wss://mobile-gateway-production-ef46.up.railway.app',
);

const String kExplorerTx = 'https://explorer.solana.com/tx/';
const String kExplorerAddr = 'https://explorer.solana.com/address/';
const String kCluster = '?cluster=devnet';

/// Devnet RPC for the wallet balance read (throtl-proven endpoint).
const String kRpc = String.fromEnvironment('QUIVO_RPC', defaultValue: 'https://rpc.magicblock.app/devnet');

/// Mobile Wallet Adapter identity (shown in the wallet's authorize prompt) + target cluster.
const String kAppName = 'Quivo';
const String kIdentityUri = 'https://quivo.fun';
const String kMwaCluster = 'devnet';

/// Domain names (.skr / .sol / any AllDomains TLD) are registered on MAINNET, so reverse-resolving
/// a connected wallet's name uses a mainnet RPC, not the devnet game RPC above.
const String kDomainRpc =
    String.fromEnvironment('QUIVO_DOMAIN_RPC', defaultValue: 'https://api.mainnet-beta.solana.com');
