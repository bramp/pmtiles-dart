import 'package:json_annotation/json_annotation.dart';

part 'server_args.g.dart';

@JsonSerializable()
class ServerArgs {
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final bool includeParentEnvironment;

  const ServerArgs({
    required this.executable,
    this.arguments = const [],
    this.workingDirectory,
    this.includeParentEnvironment = false,
  }) : assert(executable != "");

  factory ServerArgs.fromJson(Map<String, dynamic> json) =>
      _$ServerArgsFromJson(json);
  Map<String, dynamic> toJson() => _$ServerArgsToJson(this);
}
