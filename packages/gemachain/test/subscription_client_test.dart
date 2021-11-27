import 'package:gemachain/gemachain.dart';
import 'package:gemachain/src/crypto/ed25519_hd_keypair.dart';
import 'package:gemachain/src/dto/account.dart';
import 'package:gemachain/src/rpc_client/rpc_client.dart';
import 'package:gemachain/src/subscription_client/optional_error.dart';
import 'package:gemachain/src/subscription_client/subscription_client.dart';
import 'package:test/test.dart';

import 'config.dart';

void main() {
  test('accountSubscribe must return account owned by the system program',
      () async {
    const originalCarats = 10 * caratsPerGema;
    final sender = await Ed25519HDKeyPair.random();
    final recipient = await Ed25519HDKeyPair.random();
    final rpcClient = RPCClient(devnetRpcUrl);
    final signature = await rpcClient.requestAirdrop(
      address: sender.address,
      carats: originalCarats,
    );

    final client = await SubscriptionClient.connect(devnetWebsocketUrl);
    final OptionalError result =
        await client.signatureSubscribe(signature).firstWhere((_) => true);

    expect(result.err, isNull);
    // System program
    final accountStream = client.accountSubscribe(sender.address);

    // Now send some tokens
    final wallet = Wallet(signer: sender, rpcClient: rpcClient);
    await wallet.transfer(
      destination: recipient.address,
      commitment: Commitment.confirmed,
      carats: caratsPerGema,
    );

    final account = await accountStream.firstWhere(
      (Account data) => true,
    );

    expect(account.carats, lessThan(originalCarats));
  });
}
