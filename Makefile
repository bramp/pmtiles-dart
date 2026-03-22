.PHONY: all format analyze test test-ci test-dart test-flutter test-node test-chrome fix clean upgrade pub-outdated

## Run all checks (format, analyze, test)
all: format analyze test

## Format all Dart code
format:
	dart format .

## Run the analyzer across all packages
analyze:
	dart analyze

## Run all tests
test: test-dart test-flutter test-node test-chrome

## Run all tests for CI
test-ci: test

## Run native Dart tests
test-dart:
	cd packages/pmtiles && dart test

## Run Flutter tests
test-flutter:
	cd packages/pmtiles_tests && flutter test

## Run Node.js tests
test-node:
	cd packages/pmtiles && dart test --platform node
	cd packages/pmtiles_tests && dart test --platform node

## Run Chrome tests
test-chrome:
	cd packages/pmtiles && dart test --platform chrome
	cd packages/pmtiles_tests && dart test --platform chrome

## Apply auto-fixes
fix:
	dart fix --apply

## Check for outdated dependencies in all directories
pub-outdated:
	dart pub outdated
	cd packages/pmtiles && dart pub outdated
	cd packages/pmtiles_cli && dart pub outdated
	cd packages/pmtiles_tests && flutter pub outdated

## Upgrade dependencies
upgrade: pub-outdated
	dart pub upgrade --major-versions --tighten

## Delete build artifacts
clean:
	find . -name ".dart_tool" -type d -exec rm -rf {} +
