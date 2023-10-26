/// Library for reading PMTile files.
///
library;

import 'package:meta/meta.dart';

export 'src/archive.dart';
export 'src/exceptions.dart';
export 'src/types.dart';
export 'src/tile.dart';
export 'src/zxy.dart';

@visibleForTesting
export 'src/io.dart';

/// Mime type for PMTiles.
const mimeType = "application/vnd.pmtiles";
