import 'package:json_annotation/json_annotation.dart';

part 'server_args.g.dart';

@JsonSerializable()
class ServerArgs {
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;

  /// We wait for a log line that contains this string.
  final String waitFor;

  const ServerArgs({
    required this.executable,
    required this.waitFor,
    this.arguments = const [],
    this.workingDirectory,
  })  : assert(executable != ""),
        assert(waitFor != "");

  factory ServerArgs.fromJson(Map<String, dynamic> json) =>
      _$ServerArgsFromJson(json);
  Map<String, dynamic> toJson() => _$ServerArgsToJson(this);
}
