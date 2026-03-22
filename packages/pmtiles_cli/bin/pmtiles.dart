// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:pmtiles/pmtiles.dart';

class ZxyCommand extends Command<void> {
  @override
  final name = 'zxy';

  @override
  final description = 'Converts between tile ID and Z X Y.';

  @override
  String get invocation {
    return 'pmtiles zxy <tileId>\n'
        '   or: pmtiles zxy <z> <x> <y>';
  }

  @override
  Future<void> run() async {
    if (argResults!.rest.length == 1) {
      final tileId = int.parse(argResults!.rest[0]);

      print(ZXY.fromTileId(tileId));

      return;
    }

    if (argResults!.rest.length == 3) {
      final z = int.parse(argResults!.rest[0]);
      final x = int.parse(argResults!.rest[1]);
      final y = int.parse(argResults!.rest[2]);

      print(ZXY(z, x, y).toTileId());

      return;
    }

    throw UsageException('', usage);
  }
}

class ShowCommand extends Command<void> {
  ShowCommand() {
    argParser.addFlag('show-metadata', defaultsTo: true, aliases: ['m']);
    argParser.addFlag('show-root', aliases: ['r']);
  }
  @override
  final name = 'show';
  @override
  final description = 'Show metadata related to a archive.';

  @override
  String get invocation {
    return 'pmtiles show <archive>';
  }

  @override
  Future<void> run() async {
    if (argResults!.rest.length != 1) {
      throw UsageException('Must provide a single archive', usage);
    }

    final file = argResults!.rest[0];
    final tiles = await PmTilesArchive.from(file);
    try {
      print('Header:');
      print(tiles.header);

      if (argResults!['show-metadata'] as bool) {
        print('Metadata:');

        const encoder = JsonEncoder.withIndent('  ');
        final prettyJson = encoder.convert(await tiles.metadata);
        print(prettyJson);
      }

      if (argResults!['show-root'] as bool) {
        print('Root:');
        print('  ${tiles.root}');
      }
    } finally {
      await tiles.close();
    }
  }
}

class TileCommand extends Command<void> {
  TileCommand() {
    argParser.addFlag('uncompress', defaultsTo: true);
  }
  @override
  final name = 'tile';
  @override
  final description =
      'Fetch one tile from a local or remote archive and output on stdout.';

  @override
  String get invocation {
    return 'pmtiles tile [<options>] <archive> <tileId>';
  }

  @override
  Future<void> run() async {
    if (argResults!.rest.length != 2) {
      throw UsageException('', usage);
    }

    final file = argResults!.rest[0];
    final tileId = int.parse(argResults!.rest[1]);

    final tiles = await PmTilesArchive.from(file);
    try {
      // Write the binary tile to stdout.
      final tile = await tiles.tile(tileId);
      IOSink(stdout).add(tile.bytes());
    } finally {
      await tiles.close();
    }
  }
}

Future<void> main(List<String> args) async {
  final runner =
      CommandRunner<void>(
          'pmtiles',
          'A pmtiles command line tool (written in dart).',
        )
        ..addCommand(ShowCommand())
        ..addCommand(TileCommand())
        ..addCommand(ZxyCommand());

  try {
    await runner.run(args);
  } on UsageException catch (error) {
    print(error);
    exit(-1);
  }
}
