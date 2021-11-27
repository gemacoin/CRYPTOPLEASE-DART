import 'package:json_annotation/json_annotation.dart';
import 'package:gemachain/src/rpc_client/json_rpc_response_object.dart';

part 'balance_response.g.dart';

@JsonSerializable(createToJson: false)
class BalanceResponse extends JsonRpcResponse<ValueResponse<int>> {
  BalanceResponse(ValueResponse<int> result) : super(result: result);

  factory BalanceResponse.fromJson(Map<String, dynamic> json) =>
      _$BalanceResponseFromJson(json);
}
