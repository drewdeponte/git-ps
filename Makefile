prefix ?= /usr/local
bindir = $(prefix)/bin

build:
	swift build -c release --disable-sandbox

install: build
	install ".build/release/git-ps" "$(bindir)"

uninstall:
	rm -rf "$(bindir)/git-ps"

clean:
	rm -rf .build

.PHONY: build install uninstall clean
