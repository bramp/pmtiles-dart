// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_args.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServerArgs _$ServerArgsFromJson(Map<String, dynamic> json) => ServerArgs(
      executable: json['executable'] as String,
      arguments: (json['arguments'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      workingDirectory: json['workingDirectory'] as String?,
      includeParentEnvironment:
          json['includeParentEnvironment'] as bool? ?? false,
    );

Map<String, dynamic> _$ServerArgsToJson(ServerArgs instance) =>
    <String, dynamic>{
      'executable': instance.executable,
      'arguments': instance.arguments,
      'workingDirectory': instance.workingDirectory,
      'includeParentEnvironment': instance.includeParentEnvironment,
    };
