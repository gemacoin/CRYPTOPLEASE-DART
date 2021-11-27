import 'package:gemachain/gemachain.dart' show caratsPerSol;
import 'package:gemachain/src/crypto/ed25519_hd_keypair.dart';
import 'package:gemachain/src/dto/commitment.dart';
import 'package:gemachain/src/exceptions/no_associated_token_account_exception.dart';
import 'package:gemachain/src/parsed_message/parsed_instruction.dart';
import 'package:gemachain/src/parsed_message/parsed_spl_token_instruction.dart';
import 'package:gemachain/src/parsed_message/parsed_system_instruction.dart';
import 'package:gemachain/src/rpc_client/rpc_client.dart';
import 'package:gemachain/src/spl_token/spl_token.dart';
import 'package:gemachain/src/wallet.dart';
import 'package:test/test.dart';

import 'config.dart';

void main() {
  late final RPCClient rpcClient;
  late final Wallet source;
  late final Wallet destination;
  late SplToken token;

  setUpAll(() async {
    final signer = await Ed25519HDKeyPair.random();
    rpcClient = RPCClient(devnetRpcUrl);
    source = Wallet(signer: signer, rpcClient: rpcClient);
    destination =
        Wallet(signer: await Ed25519HDKeyPair.random(), rpcClient: rpcClient);
    // Add tokens to the sender
    await source.requestAirdrop(carats: 100 * caratsPerSol);
    token = await rpcClient.initializeMint(
      owner: signer,
      decimals: 2,
    );
    final associatedAccount = await source.createAssociatedTokenAccount(
      mint: token.mint,
      funder: source,
    );
    await token.mintTo(
      destination: associatedAccount.address,
      amount: _tokenMintAmount,
    );
  });

  test('Get wallet carats', () async {
    expect(await source.getCarats(), greaterThan(0));
  });

  test('Transfer SOL', () async {
    final signature = await source.transfer(
      destination: destination.address,
      carats: caratsPerSol,
    );
    expect(signature, isNotNull);
    expect(await destination.getCarats(), equals(caratsPerSol));
  });

  test('Transfer SOL with memo', () async {
    const memoText = 'Memo test string...';

    final signature = await source.transferWithMemo(
      destination: destination.address,
      carats: _caratsTransferAmount,
      memo: memoText,
    );
    expect(signature, isNotNull);

    final result =
        await rpcClient.getConfirmedTransaction(signature.toString());
    expect(result, isNotNull);
    expect(result?.transaction, isNotNull);
    final transaction = result!.transaction;
    expect(transaction.message, isNotNull);
    final txMessage = transaction.message!;
    expect(txMessage.instructions, isNotNull);
    final instructions = txMessage.instructions;
    expect(instructions.length, equals(2));
    expect(instructions[0], const TypeMatcher<ParsedInstructionSystem>());
    final parsedInstructionSystem = instructions[0] as ParsedInstructionSystem;
    expect(
        parsedInstructionSystem.parsed, isA<ParsedSystemTransferInstruction>());
    final parsedTransferInstruction =
        parsedInstructionSystem.parsed as ParsedSystemTransferInstruction;
    expect(
        parsedTransferInstruction.info.carats, equals(_caratsTransferAmount));
    expect(instructions[1], const TypeMatcher<ParsedInstructionMemo>());
    final memoInstruction = instructions[1] as ParsedInstructionMemo;
    expect(memoInstruction.memo, equals(memoText));
  });

  test('Get a token balance', () async {
    final wallet = Wallet(
      signer: await Ed25519HDKeyPair.random(),
      rpcClient: rpcClient,
    );
    expect(wallet.hasAssociatedTokenAccount(mint: token.mint),
        completion(equals(false)));

    final signature = await wallet.requestAirdrop(
      carats: caratsPerSol,
      commitment: Commitment.finalized,
    );
    expect(signature, isNotNull);
    expect(await wallet.getCarats(), equals(caratsPerSol));

    await wallet.createAssociatedTokenAccount(mint: token.mint);
    expect(wallet.hasAssociatedTokenAccount(mint: token.mint),
        completion(equals(true)));

    final tokenBalance = await wallet.getTokenBalance(mint: token.mint);
    expect(tokenBalance.decimals, equals(token.decimals));
    expect(tokenBalance.amount, equals('0'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('Fails SPL transfer if recipient has no associated token account',
      () async {
    final wallet = Wallet(
      signer: await Ed25519HDKeyPair.random(),
      rpcClient: rpcClient,
    );
    expect(
      source.transferSplToken(
        destination: wallet.address,
        amount: 100,
        mint: token.mint,
      ),
      throwsA(isA<NoAssociatedTokenAccountException>()),
    );
  });

  test('Transfer SPL tokens successfully', () async {
    final wallet = Wallet(
      signer: await Ed25519HDKeyPair.random(),
      rpcClient: rpcClient,
    );
    await wallet.createAssociatedTokenAccount(
      mint: token.mint,
      funder: source,
    );
    final signature = await source.transferSplToken(
      destination: wallet.address,
      amount: 40,
      mint: token.mint,
    );
    expect(signature, isNotNull);

    final tokenBalance = await wallet.getTokenBalance(mint: token.mint);
    expect(tokenBalance.amount, equals('40'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('Transfer SPL tokens with memo', () async {
    final wallet = Wallet(
      signer: await Ed25519HDKeyPair.random(),
      rpcClient: rpcClient,
    );
    // Create the associated account for the recipient
    await wallet.createAssociatedTokenAccount(
      mint: token.mint,
      funder: source,
    );
    const memoText = 'Memo test string...';

    final signature = await source.transferSplTokenWithMemo(
      mint: token.mint,
      destination: wallet.address,
      amount: 40,
      memo: memoText,
    );
    expect(signature, isNotNull);

    final result =
        await rpcClient.getConfirmedTransaction(signature.toString());
    expect(result, isNotNull);
    expect(result?.transaction, isNotNull);
    final transaction = result!.transaction;
    expect(transaction.message, isNotNull);
    final txMessage = transaction.message!;
    expect(txMessage.instructions, isNotNull);
    final instructions = txMessage.instructions;
    expect(instructions.length, equals(2));
    expect(instructions[0], const TypeMatcher<ParsedInstructionSplToken>());
    expect(instructions[1], const TypeMatcher<ParsedInstructionMemo>());
    final memoInstruction = instructions[1] as ParsedInstructionMemo;
    expect(memoInstruction.memo, equals(memoText));
    final splTokenInstruction = instructions[0] as ParsedInstructionSplToken;
    expect(
        splTokenInstruction.parsed, isA<ParsedSplTokenTransferInstruction>());
    final parsedSplTokenInstruction =
        splTokenInstruction.parsed as ParsedSplTokenTransferInstruction;
    expect(parsedSplTokenInstruction.type, equals('transfer'));
    expect(parsedSplTokenInstruction.info,
        isA<ParsedSplTokenTransferInformation>());
    expect(parsedSplTokenInstruction.info.amount, '40');
    final tokenBalance = await wallet.getTokenBalance(mint: token.mint);
    expect(tokenBalance.amount, equals('40'));
  }, timeout: const Timeout(Duration(minutes: 2)));
}

const _tokenMintAmount = 1000;
const _caratsTransferAmount = 5 * caratsPerSol;
