import 'package:json_annotation/json_annotation.dart';

part 'server_args.g.dart';

@JsonSerializable()
class ServerArgs {
  const ServerArgs({
    required this.executable,
    this.arguments = const [],
    this.workingDirectory,
    this.includeParentEnvironment = false,
  }) : assert(executable != '');

  factory ServerArgs.fromJson(Map<String, dynamic> json) =>
      _$ServerArgsFromJson(json);
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final bool includeParentEnvironment;
  Map<String, dynamic> toJson() => _$ServerArgsToJson(this);
}
