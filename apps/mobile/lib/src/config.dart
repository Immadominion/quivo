/// Runtime config. Override the gateway for a physical device with:
///   `flutter run --dart-define=QUIVO_GATEWAY=ws://YOUR-MAC-LAN-IP:2568`
/// (the iOS simulator shares the Mac's network, so localhost works there).
const String kGateway = String.fromEnvironment('QUIVO_GATEWAY', defaultValue: 'ws://localhost:2568');

const String kExplorerTx = 'https://explorer.solana.com/tx/';
const String kExplorerAddr = 'https://explorer.solana.com/address/';
const String kCluster = '?cluster=devnet';

/// Devnet RPC for the wallet balance read (throtl-proven endpoint).
const String kRpc = String.fromEnvironment('QUIVO_RPC', defaultValue: 'https://rpc.magicblock.app/devnet');
