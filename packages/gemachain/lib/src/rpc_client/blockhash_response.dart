import 'package:json_annotation/json_annotation.dart';
import 'package:gemachain/src/dto/blockhash.dart';
import 'package:gemachain/src/rpc_client/json_rpc_response_object.dart';

part 'blockhash_response.g.dart';

@JsonSerializable(createToJson: false)
class BlockhashResponse extends JsonRpcResponse<ValueResponse<Blockhash>> {
  BlockhashResponse(ValueResponse<Blockhash> result) : super(result: result);

  factory BlockhashResponse.fromJson(Map<String, dynamic> json) =>
      _$BlockhashResponseFromJson(json);
}
