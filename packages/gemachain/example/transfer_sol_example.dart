import 'package:gemachain/gemachain.dart';

Future<void> example() async {
  final rpcClient = RPCClient(_rpcClientUrl);
  // Create a wallet
  final source = Wallet(
    signer: await Ed25519HDKeyPair.random(),
    rpcClient: rpcClient,
  );

  // Because this is an example, let's put some carats into the source
  // wallet. Note that this will of course not work on the main network.
  await source.requestAirdrop(carats: 5);

  // Final Destination (so funny :D)
  final destination = await Ed25519HDKeyPair.random();

  // Finally transfer the tokens to the recipient
  await source.transferWithMemo(
    destination: destination.address,
    carats: 1,
    memo: 'You can add a message here!',
  );

  // Compute the fee that source payed
  final fee = 4 - await source.getCarats();

  print('You payed $fee carats for the network fee');

  // To confirm that it worked let's see if there's any balance
  // in the recipients wallet
  final carats = await rpcClient.getBalance(destination.address);
  if (carats == 1) {
    print('Good, it worked.');
  } else {
    print('Bad, it failed.');
  }
}

const _rpcClientUrl = 'https://api.devnet.solana.com';
