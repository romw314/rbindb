#!/bin/bash
set -e

detq() {
	if grep -q "^$1:$name-$tag " ../../pkgs.conf; then
		q="^$1:$name-$tag "
	else
		q="^$1:$name "
	fi
}

grep '^repo:' pkgs.conf | while read name repo; do
	name="${name:5}"
	echo "=> Building $name"
	echo "==> Checking cache"
	if grep -q "^$name$" build_cache.txt; then
		echo "===> Skipping"
		continue
	fi
	echo "===> Building"
	rm -rf pkgs/"$name" dist/"$name"-*
	mkdir -p pkgs/"$name"
	cd pkgs/"$name"
	echo "==> Cloning repo"
	if ! git clone "$repo" . &>../error.log; then
		cat ../error.log
		exit 2
	fi
	echo "==> Building versions"
	git tag -l | while read tag; do
		echo "===> Building $name-$tag"
		if ! (
			mkdir -p ../../dist/"$name"-"$tag"
			git checkout -q "$tag"
			if grep -q -E "^make:$name(-$tag| )" ../../pkgs.conf; then
				detq make
				grep "$q" ../../pkgs.conf | tail -n1 | sed -E 's/^make:[A-Za-z0-9_-]+ //' | sh
			elif [ -x build.sh ]; then
				./build.sh
			elif [ -f build.sh ]; then
				sh build.sh
			elif [ -f CMakeLists.txt ]; then
				if [ -f CMakePresets.json ]; then
					if grep -q workflow CMakePresets.json; then
						cmake --workflow --preset default
					else
						cmake --preset default
						cmake --build --preset default
					fi
				else
					cd "$(mktemp -d build_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX)"
					cmake ..
					cmake --build .
					cd ..
				fi
			elif [ -f configure.ac ]; then
				autoreconf --install
				./configure
				make
			elif [ -f configure ]; then
				./configure
				make
			elif [ -f Makefile -o -f makefile -o -f GNUmakefile ]; then
				make
			else
				echo >&2 "ERR: Cannot determine build system for $name-$tag"
			fi
			detq dist
			grep "$q" ../../pkgs.conf | cut -f2,3 -d' ' | while read src out; do
				cp -r "$src" ../../dist/"$name"-"$tag"/"$out"
			done
		) &>../error.log; then
			cat ../error.log
			exit 1
		fi
	done
	cd ../..
	echo "==> Updating build cache"
	echo "$name" >> build_cache.txt
done
