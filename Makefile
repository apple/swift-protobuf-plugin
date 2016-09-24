#
# Key targets in this Makefile:
#
# Note:
# * The `all` and `install` targets require `swift` command-line tools
#   be installed, but nothing else.
# * Other targets require protoc be already installed, `update` requires
#   a source checkout of Google's protobuf project.
#
# make all
#   Build protoc-gen-swift from current sources
# make install BINDIR=/usr/local/bin
#   Copy protoc-gen-swift to BINDIR
# make regenerate
#   Rebuild Swift source used by protoc-gen-swift from proto files
#   (requires protoc-gen-swift be already compiled and protoc is in the $PATH)
# make update PROTOBUF_PROJECT_DIR=../protobuf
#   Copy useful proto files from Google's protobuf project
#   (requires a source checkout of Google's protobuf project)
#   (only needed if Google's descriptor or plugin protos have changed)
# make test
#   Check generated Swift by comparing output to stored reference files
#   (Requires protoc-gen-swift be already compiled and protoc is in $PATH)
# make reference
#   Replace reference files
#   (Requires protoc-gen-swift be already compiled and protoc is in $PATH)
#   WARNING:  You must MANUALLY verify the updated files before committing them
#

#
# How to build and test this project:
#
# 0. Install protoc (recent 3.0.0 or later)
# 1. Build the project
#    $ make
# 2. Check that the generated output is unchanged
#    $ make test
# 3. If no changes, install
#    $ make install BINDIR=/usr/local/bin
#
# If the generated output has changed,
#
# 1. Update the reference files
#    $ make reference
# 2. MANUALLY verify that the changes are correct
#    $ git diff Test/reference
# 3. Commit the changed reference files
#    $ git commit Test/reference
#
# If protobuf project has changed descriptor.proto or plugin.proto,
#
# 1. Get the new proto files
#    $ make update PROTOBUF_PROJECT_DIR=../protobuf
# 2. Regenerate the protos used by protoc-gen-swift
#    $ make regenerate
# 3. Rebuild and test as above
#
#

# How to run a 'swift' executable that supports the 'swift build' command.
SWIFT=swift

# How to run a working version of protoc
PROTOC=protoc

# Path to a source checkout of Google's protobuf project, used
# by the 'update' target.
PROTOBUF_PROJECT_DIR=../protobuf

# Installation directory
BINDIR=/usr/local/bin

INSTALL=install

PROTOC_GEN_SWIFT=.build/debug/protoc-gen-swift

# Source code for the plugin
SOURCES= \
	Sources/protoc-gen-swift/CodePrinter.swift \
	Sources/protoc-gen-swift/Context.swift \
	Sources/protoc-gen-swift/EnumGenerator.swift \
	Sources/protoc-gen-swift/ExtensionGenerator.swift \
	Sources/protoc-gen-swift/FileGenerator.swift \
	Sources/protoc-gen-swift/FileIo.swift \
	Sources/protoc-gen-swift/MessageFieldGenerator.swift \
	Sources/protoc-gen-swift/MessageGenerator.swift \
	Sources/protoc-gen-swift/OneofGenerator.swift \
	Sources/protoc-gen-swift/ReservedWords.swift \
	Sources/protoc-gen-swift/StringUtils.swift \
	Sources/protoc-gen-swift/Version.swift \
	Sources/protoc-gen-swift/main.swift \
	Sources/PluginLibrary/descriptor.pb.swift \
	Sources/PluginLibrary/plugin.pb.swift \
	Sources/PluginLibrary/swift-options.pb.swift

.PHONY: default all build check clean install test update update-ref

default: build

all: build

build: protoc-gen-swift

protoc-gen-swift: $(PROTOC_GEN_SWIFT)
	cp $< $@

$(PROTOC_GEN_SWIFT): ${SOURCES}
	${SWIFT} build

install:
	${INSTALL} ${PROTOC_GEN_SWIFT} ${BINDIR}

check: test

clean:
	rm -f protoc-gen-swift
	rm -rf .build
	rm -rf Test/_generated

# Verifies that the output of protoc-gen-test exactly matches
# the master reference files stored in the Reference directory.
#
# This assumes, of course, that the various Reference files
# contain exactly the output that protoc-gen-swift should generate.
# This is a good test if you are refactoring the code in ways
# that should not affect the output.  Otherwise, you will need to:
#  * Manually check the differences and run `make reference` to update the
#    reference files when you are convinced the changes are correct
#  * Run the test suite included in swift-protobuf-runtime to verify that
#    the functionality is still correct.
test: build
	rm -rf _test && mkdir -p _test
	ABS_TOPDIR=`pwd`; \
	rm -rf _test; \
	for p in `cd Protos; find . -type f -name '*.proto'`; do \
		d=`dirname $$p`; \
		mkdir -p _test/$$d; \
		${PROTOC} --plugin=$${ABS_TOPDIR}/protoc-gen-swift --swift_out=_test/$$d -I Protos Protos/$$p; \
	done
	diff -r _test Reference

#
# Rebuild the reference files by running the current
# version of protoc-gen-swift against our menagerie
# of sample protos.
#
# If you do this, you MUST MANUALLY verify these files
# before checking them in, since the new checkin will
# become the new master reference.
#
reference: build
	ABS_TOPDIR=`pwd`; \
	rm -rf Reference; \
	for p in `cd Protos; find . -type f -name '*.proto'`; do \
		d=`dirname $$p`; \
		mkdir -p Reference/$$d; \
		${PROTOC} --plugin=$${ABS_TOPDIR}/protoc-gen-swift --swift_out=Reference/$$d -I Protos Protos/$$p; \
	done

#
# Regenerates plugin.pb.swift and descriptor.pb.swift from protobuf sources.
# This defines the communications between protoc and the plugin.
#
# This could be a prerequisite for 'build' except that it requires
# the plugin to already be built and also requires protoc to be installed.
#
regenerate:
	${PROTOC} --plugin=$(PROTOC_GEN_SWIFT) --swift_out=Sources/PluginLibrary -I Protos Protos/google/protobuf/descriptor.proto Protos/google/protobuf/compiler/plugin.proto Protos/swift-options.proto

#
# Updates the local copy of Google protos that we need for the plugin.
#
# Note: This is only necessary when Google changes plugin.proto (almost never)
# or descriptor.proto (rarely).  You should `make reference` to update the
# reference files after doing this.
update:
	ABS_PBDIR=`cd ${PROTOBUF_PROJECT_DIR}; pwd`; \
	cp $${ABS_PBDIR}/src/google/protobuf/descriptor.proto Protos/google/protobuf/
	cp $${ABS_PBDIR}/src/google/protobuf/compiler/plugin.proto Protos/google/protobuf/compiler

