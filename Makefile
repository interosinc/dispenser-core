help:
	@cat Makefile

build:
	stack build

clean:
	stack clean

dist-clean:
	\rm -rf .stack-work

ghcid:
	stack exec -- ghcid -c 'stack ghci' --restart stack.yaml

hlint:
	stack exec hlint .

longboye-all:
	longboye imports src
	longboye imports test
	longboye pragmas src
	longboye pragmas test

setup:
	stack setup

test:
	stack test

watch:
	stack build --fast --file-watch

watch-test:
	stack test --fast --file-watch

b: build
hl: hlint
lba: longboye-all
s: setup
w: watch
t: test
wt: watch-test

.PHONY: test
