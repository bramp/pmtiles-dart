## 2.2.0

 - Added strict archive validation for PMTiles v3.4 directory invariants.
 - Added support for PMTiles v3.5 `mlt` tile types.
 - Added Terrarium helpers for PMTiles v3.6 terrain metadata and elevation decoding.
 - Updated dependencies to their latest compatible versions.

## 2.1.0

 - Removed `src/io.dart` from the public API (was previously `@visibleForTesting`).
 - Bumped `latlong2` dependency from `^0.9.1` to `^0.10.1`.
 - Bumped all other dependencies to their latest compatible versions.
 - Tightened analyzer configuration and cleaned up lints throughout the core library.
 - Improved print-friendly output in example and CLI.
 - Clarified PMTiles spec link as PMTiles v3.3 in README.

## 2.0.0

 - **BREAKING**: Updated SDK constraint to Dart 3 (`^3.11.3`).
 - Updated all dependencies to their latest compatible versions.
 - Standardized analysis options with `very_good_analysis`.
 - Migrated from Melos to a standard Dart workspace.
 - Adopted standardized `Makefile` and GitHub workflows.

## 1.3.0

 - Added support for dart2js builds

## 1.2.0

 - Bumped dependencies to align with latest flutter.

## 1.1.0

 - Added a new API for batch reading of tiles.

## 1.0.0

- Initial version.
