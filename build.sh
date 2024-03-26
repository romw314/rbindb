#!/bin/bash
set -e
rm -rf pkgs dist
grep '^repo:' pkgs.conf | while read name repo; do
	name="${name:5}"
	mkdir -p pkgs/"$name"
	cd pkgs/"$name"
	if ! git clone "$repo" . &>../error.log; then
		cat ../error.log
		exit 2
	fi
	git tag -l | while read tag; do
		echo "=> Building $name-$tag"
		if ! (
			mkdir -vp ../../dist/"$name"-"$tag"
			git checkout "$tag"
			if [ -x build.sh ]; then
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
			fi
			cat ../../pkgs.conf | grep "^dist:$name" | cut -f2,3 -d' ' | while read src out; do
				cp -r "$src" ../../dist/"$name"-"$tag"/"$out"
			done
		) &>../error.log; then
			cat ../error.log
			exit 1
		fi
	done
	cd ..
done
