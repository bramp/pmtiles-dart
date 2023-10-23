import 'package:meta/meta.dart';
import 'package:protobuf/protobuf.dart';

@immutable
class Directory {
  final List<int> tileIds;
  final List<int> runLengths;
  final List<int> lengths;
  final List<int> offsets;

  /// The number of tiles in the directory. If null, the number of tiles is unknown.
  /// Should match the [numberOfTileEntries] value in the [Header].
  /// TODO Validate the above statement.
  final int? totalTiles;

  Directory({
    required this.tileIds,
    required this.runLengths,
    required this.lengths,
    required this.offsets,
    this.totalTiles,
  })  : assert(tileIds.length == runLengths.length &&
            runLengths.length == lengths.length &&
            lengths.length == offsets.length),
        assert(totalTiles == null || totalTiles >= tileIds.length);

  static Directory from(List<int> uncompressed) {
    final reader = CodedBufferReader(uncompressed);

    final n = reader.readInt64();

    // TODO final tiles = <ZXY>[];
    final tileIds = <int>[];
    final runLengths = <int>[];
    final lengths = <int>[];
    final offsets = <int>[];

    // TODO Due to how ints work, `n.toInt()` may lose percesion, and we should
    // check if that impacts us.
    // TODO I bet these can all be readUint32, and it'll be fine!
    int lastId = 0;
    for (var i = 0; i < n.toInt(); i++) {
      final delta = reader.readInt64().toInt();
      lastId += delta;

      tileIds.add(lastId);

      //tiles.add(ZXY.fromTileId(lastId));
    }

    int totalTiles = 0;
    for (var i = 0; i < n.toInt(); i++) {
      final run = reader.readInt64().toInt();
      totalTiles += run;
      runLengths.add(run);
    }
    for (var i = 0; i < n.toInt(); i++) {
      lengths.add(reader.readInt64().toInt());
    }
    for (var i = 0; i < n.toInt(); i++) {
      offsets.add(reader.readInt64().toInt());
    }

    assert(reader.isAtEnd(), "We should have read everything");

    return Directory(
      tileIds: tileIds,
      runLengths: runLengths,
      lengths: lengths,
      offsets: offsets,
      totalTiles,
    );
  }

  @override
  String toString() {
    return '''
      n: ${tileIds.length},
      deltaTileIds: $tileIds,
      runLengths: $runLengths,
      lengths: $lengths,
      offsets: $offsets,
    ''';
  }
}
