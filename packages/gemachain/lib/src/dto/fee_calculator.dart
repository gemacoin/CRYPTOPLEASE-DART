import 'package:json_annotation/json_annotation.dart';

part 'fee_calculator.g.dart';

/// Fee calculator object which is part of a [Blockhash] object.
@JsonSerializable(createToJson: false)
class FeeCalculator {
  FeeCalculator({required this.caratsPerSignature});

  factory FeeCalculator.fromJson(Map<String, dynamic> json) =>
      _$FeeCalculatorFromJson(json);

  final int caratsPerSignature;
}
