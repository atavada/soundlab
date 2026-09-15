.PHONY: all build test bundle run clean

all: bundle

build:
	swift build

test:
	swift test

bundle:
	./scripts/bundle.sh

run: bundle
	open build/SoundLab.app

clean:
	rm -rf .build build
