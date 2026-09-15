.PHONY: all build test bundle run clean icon dmg

all: bundle

build:
	swift build

test:
	swift test

icon:
	./scripts/generate-icon.sh

bundle:
	./scripts/bundle.sh

dmg: bundle
	./scripts/package-dmg.sh

run: bundle
	open build/SoundLab.app

clean:
	rm -rf .build build
