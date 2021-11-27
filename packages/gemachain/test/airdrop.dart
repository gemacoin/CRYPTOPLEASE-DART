import 'package:gemachain/gemachain.dart';
import 'package:gemachain/src/crypto/ed25519_hd_keypair.dart';
import 'package:gemachain/src/dto/commitment.dart';

Future<void> airdrop(
  RPCClient client,
  Ed25519HDKeyPair wallet, {
  int? sol,
  int? carats,
}) async {
  // Request some tokens first
  final int? amount = sol != null ? sol * caratsPerGema : carats;
  if (amount == null) {
    throw const FormatException('either specify "sol" or "carats"');
  }
  final txSignature = await client.requestAirdrop(
    address: wallet.address,
    carats: amount,
  );
  await client.waitForSignatureStatus(txSignature, Commitment.finalized);
}
