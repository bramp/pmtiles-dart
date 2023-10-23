import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:pmtiles/pmtiles.dart';

class ZxyCommand extends Command {
  @override
  final name = "zxy";

  @override
  final description = "Converts between tile ID and Z X Y.";

  @override
  String get invocation {
    return "pmtiles zxy <tileId>\n"
        "   or: pmtiles zxy <z> <x> <y>";
  }

  @override
  void run() async {
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

    throw UsageException("", usage);
  }
}

class ShowCommand extends Command {
  @override
  final name = "show";
  @override
  final description = "Show metadata related to a archive.";

  ShowCommand() {
    argParser.addFlag('show-root', defaultsTo: false, aliases: ['r']);
  }

  @override
  String get invocation {
    return "pmtiles show <archive>";
  }

  @override
  void run() async {
    if (argResults!.rest.length != 1) {
      throw UsageException("Must provide a single archive", usage);
    }

    final file = argResults!.rest[0];
    final tiles = await PmTilesArchive.from(file);
    try {
      print("Header:");
      print(tiles.header);

      print("Metadata:");
      print("      ${await tiles.metadata}");

      if (argResults!['show-root']) {
        print("Root:");
        print("      ${tiles.root}");
      }
    } finally {
      await tiles.close();
    }
  }
}

class TileCommand extends Command {
  @override
  final name = "tile";
  @override
  final description =
      "Fetch one tile from a local or remote archive and output on stdout.";

  TileCommand() {
    argParser.addFlag('uncompress', defaultsTo: true);
  }

  @override
  String get invocation {
    return "pmtiles tile [<options>] <archive> <tileId>";
  }

  @override
  void run() async {
    if (argResults!.rest.length != 2) {
      throw UsageException("", usage);
    }

    final file = argResults!.rest[0];
    final tileId = int.parse(argResults!.rest[1]);

    final tiles = await PmTilesArchive.from(file);
    try {
      // Write the binary tile to stdout.
      IOSink(stdout).add(await tiles.tile(tileId));
    } finally {
      await tiles.close();
    }
  }
}

main(List<String> args) async {
  CommandRunner("pmtiles", "A pmtiles command line tool (written in dart).")
    ..addCommand(ShowCommand())
    ..addCommand(TileCommand())
    ..addCommand(ZxyCommand())
    ..run(args).catchError((error) {
      if (error is! UsageException) throw error;
      print(error);
      exit(-1);
    });
}
