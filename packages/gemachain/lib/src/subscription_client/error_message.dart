import 'package:json_annotation/json_annotation.dart';
import 'package:gemachain/src/subscription_client/abstract_message.dart';
import 'package:gemachain/src/subscription_client/subscribe_error.dart';

part 'error_message.g.dart';

@JsonSerializable(createToJson: false)
class ErrorMessage implements SubscriptionMessage {
  const ErrorMessage({
    required this.error,
    required this.id,
  });

  factory ErrorMessage.fromJson(Map<String, dynamic> json) =>
      _$ErrorMessageFromJson(json);

  final SubscribeError error;
  final int id;
}