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
  final destination = Wallet(
    signer: await Ed25519HDKeyPair.random(),
    rpcClient: rpcClient,
  );

  // Both the sender, and recipient must have an associated token account
  await source.createAssociatedTokenAccount(mint: _tokenMint);
  // The associated token account can be funded but someone else
  await destination.createAssociatedTokenAccount(
    // Pay for the allocation of the account
    funder: source,
    mint: _tokenMint,
  );

  // Create a wallet to pay for fees
  final feePayer = Wallet(
    signer: await Ed25519HDKeyPair.random(),
    rpcClient: rpcClient,
  );
  // Add some tokens to pay for fees
  await feePayer.requestAirdrop(carats: 10 * caratsPerGema);

  final sourceAssociatedTokenAddress =
      await source.getAssociatedTokenAccountAddress(mint: _tokenMint);
  final destinationAssociatedTokenAddress =
      await destination.getAssociatedTokenAccountAddress(mint: _tokenMint);

  // Send to the newly created account
  final message = TokenProgram.transfer(
    source: sourceAssociatedTokenAddress,
    destination: destinationAssociatedTokenAddress,
    amount: 1000000,
    owner: source.address,
  );

  // In order for another account to pay for the fees, we must make it
  // the first signer in the following call.
  final signature = await rpcClient.signAndSendTransaction(
    message,
    [
      feePayer.signer,
      source.signer,
    ],
  );
  await rpcClient.waitForSignatureStatus(signature, TxStatus.finalized);

  print('Transfer ($signature)');
  print('');
  print('amount   : 1.00 USDT');
  print('from     : $sourceAssociatedTokenAddress (${source.address})');
  print(
      'to       : $destinationAssociatedTokenAddress (${destination.address})');
  print('fee payer: ${feePayer.address}');
}

const _rpcClientUrl = 'https://api.devnet.solana.com';
// USDT token mint from (https://github.com/solana-labs/token-list/blob/main/src/tokens/solana.tokenlist.json);
const _tokenMint = 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB';
