import 'package:gemachain/gemachain.dart';
import 'package:gemachain/src/crypto/ed25519_hd_keypair.dart';
import 'package:gemachain/src/dto/commitment.dart';
import 'package:gemachain/src/encoder/message.dart';
import 'package:gemachain/src/rpc_client/rpc_client.dart';
import 'package:gemachain/src/rpc_client/transaction_signature.dart';
import 'package:gemachain/src/spl_token/associated_account.dart';
import 'package:gemachain/src/spl_token/spl_token.dart';
import 'package:gemachain/src/spl_token/token_amount.dart';
import 'package:gemachain/src/token_program/token_program.dart';

/// Convenient object for common operations
class Wallet {
  Wallet({
    required this.signer,
    required RPCClient rpcClient,
  }) : _rpcClient = rpcClient;

  Future<TransactionSignature> _genericTransfer({
    required String source,
    required String destination,
    required int carats,
    required Commitment commitment,
    String? memo,
  }) async {
    final instructions = [
      SystemInstruction.transfer(
        source: source,
        destination: destination,
        carats: carats,
      ),
      if (memo != null) MemoInstruction(signers: [source], memo: memo),
    ];

    final message = Message(
      instructions: instructions,
    );

    final signature = await _rpcClient.signAndSendTransaction(
      message,
      [signer],
    );
    await _rpcClient.waitForSignatureStatus(signature, commitment);

    return signature;
  }

  /// Creates a solana transfer message to send [carats] SOL tokens from [source]
  /// to [destination].
  ///
  /// For [commitment] parameter description [see this document][see this document]
  /// [Commitment.processed] is not supported as [commitment].
  ///
  /// [see this document]: https://docs.solana.com/developing/clients/jsonrpc-api#configuring-state-commitment
  Future<TransactionSignature> transfer({
    required String destination,
    required int carats,
    Commitment commitment = Commitment.finalized,
  }) =>
      _genericTransfer(
        source: address,
        destination: destination,
        carats: carats,
        commitment: commitment,
      );

  /// Creates a solana transfer message to send [carats] SOL tokens from [source]
  /// to [destination].
  ///
  /// To add additional data to the transaction you can use the [memo] field.
  /// It accepts an arbitrary string of utf-8 characters. As of now the maximum
  /// allowed length for the memo is 566 bytes of utf-8 data.
  ///
  /// NOTE: This constructor creates a transaction with 2 instructions when a [memo]
  /// is provided.
  ///
  /// For [commitment] parameter description [see this document][see this document]
  /// [Commitment.processed] is not supported as [commitment].
  ///
  /// [see this document]: https://docs.solana.com/developing/clients/jsonrpc-api#configuring-state-commitment
  Future<TransactionSignature> transferWithMemo({
    required String destination,
    required int carats,
    required String memo,
    Commitment commitment = Commitment.finalized,
  }) =>
      _genericTransfer(
        source: address,
        destination: destination,
        carats: carats,
        memo: memo,
        commitment: commitment,
      );

  /// Request airdrop for [amount] to this wallet's account.
  ///
  /// For [commitment] parameter description [see this document][see this document]
  /// [Commitment.processed] is not supported as [commitment].
  ///
  /// [see this document]: https://docs.solana.com/developing/clients/jsonrpc-api#configuring-state-commitment
  Future<TransactionSignature> requestAirdrop({
    required int carats,
    Commitment commitment = Commitment.finalized,
  }) async {
    final signature = await _rpcClient.requestAirdrop(
      address: address,
      carats: carats,
      commitment: commitment,
    );
    await _rpcClient.waitForSignatureStatus(signature, commitment);

    return signature;
  }

  /// Transfers [amount] SPL token with [mint] from this wallet to the
  /// [destination] address.
  ///
  /// For [commitment] parameter description [see this document][see this document]
  /// [Commitment.processed] is not supported as [commitment].
  ///
  /// [see this document]: https://docs.solana.com/developing/clients/jsonrpc-api#configuring-state-commitment
  Future<TransactionSignature>? transferSplToken({
    required String mint,
    required String destination,
    required int amount,
    Commitment commitment = Commitment.finalized,
  }) async {
    final token = await SplToken.readonly(mint: mint, rpcClient: _rpcClient);

    return token.transfer(
      source: address,
      amount: amount,
      destination: destination,
      owner: signer,
      commitment: commitment,
    );
  }

  /// Transfers [amount] SPL token with [mint] from this wallet to the
  /// [destination] address with a [memo].
  ///
  /// For [commitment] parameter description [see this document][see this document]
  /// [Commitment.processed] is not supported as [commitment].
  ///
  /// [see this document]: https://docs.solana.com/developing/clients/jsonrpc-api#configuring-state-commitment
  Future<TransactionSignature>? transferSplTokenWithMemo({
    required String mint,
    required String destination,
    required int amount,
    required String memo,
    Commitment commitment = Commitment.finalized,
  }) async {
    final token = await SplToken.readonly(mint: mint, rpcClient: _rpcClient);
    final source = await token.computeAssociatedAddress(owner: address);

    final message = Message(
      instructions: [
        TokenInstruction.transfer(
          source: source,
          destination: await token.computeAssociatedAddress(owner: destination),
          amount: amount,
          owner: address,
        ),
        MemoInstruction(
          signers: [address],
          memo: memo,
        ),
      ],
    );

    final signature = await _rpcClient.signAndSendTransaction(
      message,
      [signer],
    );
    await _rpcClient.waitForSignatureStatus(signature, commitment);

    return signature;
  }

  /// Create the account associated to the SPL token [mint] for this wallet.
  ///
  /// If you want to use another wallet as a funder use the [funder] parameter.
  ///
  /// Also adds the token to the wallet object.
  ///
  /// For [commitment] parameter description [see this document][see this document]
  /// [Commitment.processed] is not supported as [commitment].
  ///
  /// [see this document]: https://docs.solana.com/developing/clients/jsonrpc-api#configuring-state-commitment
  Future<AssociatedTokenAccount> createAssociatedTokenAccount({
    required String mint,
    Commitment? commitment,
    Wallet? funder,
  }) async {
    final token = await SplToken.readonly(mint: mint, rpcClient: _rpcClient);
    final associatedTokenAccount = await token.createAssociatedAccount(
      owner: address,
      funder: funder?.signer ?? signer,
    );

    return associatedTokenAccount;
  }

  /// Whether this wallet has an associated token account for the SPL token [mint].
  Future<bool> hasAssociatedTokenAccount({
    required String mint,
  }) async {
    Iterable<AssociatedTokenAccount> accounts;
    final token = await SplToken.readonly(mint: mint, rpcClient: _rpcClient);
    final associatedTokenAddress = await token.computeAssociatedAddress(
      owner: address,
    );
    try {
      accounts = await _rpcClient.getTokenAccountsByOwner(
        owner: address,
        mint: token.mint,
      );
    } on FormatException {
      accounts = [];
    }
    return accounts.any((a) => a.address == associatedTokenAddress);
  }

  /// Get the account associated to the SPL token [mint] for this wallet.
  ///
  /// Note: this method always returns the address because it is computed
  /// when the [Wallet.loadToken()] method is called
  Future<String> getAssociatedTokenAccountAddress({
    required String mint,
  }) async {
    final token = await SplToken.readonly(mint: mint, rpcClient: _rpcClient);
    return token.computeAssociatedAddress(owner: address);
  }

  /// Get token [mint] balance for this wallet's account.
  ///
  /// For [commitment] parameter description [see this document][see this document]
  /// [Commitment.processed] is not supported as [commitment].
  ///
  /// [see this document]: https://docs.solana.com/developing/clients/jsonrpc-api#configuring-state-commitment
  Future<TokenAmount> getTokenBalance({
    required String mint,
    Commitment? commitment,
  }) async =>
      _rpcClient.getTokenAccountBalance(
        associatedTokenAccountAddress: await getAssociatedTokenAccountAddress(
          mint: mint,
        ),
        commitment: commitment,
      );

  /// Get the balance in carats for this wallet's account
  ///
  /// For [commitment] parameter description [see this document][see this document]
  /// [Commitment.processed] is not supported as [commitment].
  ///
  /// [see this document]: https://docs.solana.com/developing/clients/jsonrpc-api#configuring-state-commitment
  Future<int> getCarats({Commitment? commitment}) =>
      _rpcClient.getBalance(address, commitment: commitment);

  /// The address associated to this wallet
  String get address => signer.address;

  /// The [signer] associated to this wallet. This is exported
  /// because it can be needed in some places.
  final Ed25519HDKeyPair signer;

  final RPCClient _rpcClient;
}
