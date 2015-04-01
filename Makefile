###############################################################################
# libBIL Makefile                                                             #
#                                                                             #
# Copyright (c) 2014, Sang Kil Cha                                            #
# All rights reserved.                                                        #
# This software is free software; you can redistribute it and/or              #
# modify it under the terms of the GNU Library General Public                 #
# License version 2, with the special exception on linking                    #
# described in file LICENSE.                                                  #
#                                                                             #
# This software is distributed in the hope that it will be useful,            #
# but WITHOUT ANY WARRANTY; without even the implied warranty of              #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                        #
###############################################################################

OCAMLBUILD=ocamlbuild

GIT_VERSION := $(shell git describe --always --abbrev=10 --dirty=-working \
	         2>/dev/null)
OS_TYPE := $(shell uname)
DIST_VERSION := $(shell head -n 1 ReleaseNotes.md | awk '{print $$4}')
OFUZZ_DISTDIR := ofuzz-$(DIST_VERSION)
OFUZZ_VERSION=src/ofuzzversion.ml
OFUZZ_DOCDIR=ofuzz.docdir
OFUZZ_SUBDIRS=-Is src,src/testgen,src/scheduling -Xs buildtools
COMPATIBILITY=src/compatibility.ml

all: depcheck version
	$(OCAMLBUILD) $(OFUZZ_SUBDIRS) ofuzz.native minimizer.native

version:
ifeq ($(GIT_VERSION),)
	@echo "let string () = \"$(DIST_VERSION)\"" \
		> $(OFUZZ_VERSION)
else
	@echo "let string () = \"$(DIST_VERSION)-$(GIT_VERSION)\"" \
		> $(OFUZZ_VERSION)
endif
	@echo "let ostype () = \"$(OS_TYPE)\"" >> $(OFUZZ_VERSION)
	@./ocaml-compatibility.sh > $(COMPATIBILITY)

unittest: unittest/Makefile
	@make -C unittest

doc: depcheck version
	rm -rf $(OFUZZ_DOCDIR)
	$(OCAMLBUILD) $(OFUZZ_SUBDIRS) $(OFUZZ_DOCDIR)/index.html

clean: depcheck
	$(OCAMLBUILD) -clean
	@rm -f $(OFUZZ_VERSION)
	@rm -f $(COMPATIBILITY)

depcheck: Makefile.dep
	@buildtools/depcheck.sh $<

dist: all doc
	@rm -rf $(OFUZZ_DISTDIR)
	@mkdir -p $(OFUZZ_DISTDIR)/bin
	@mkdir -p $(OFUZZ_DISTDIR)/docs
	@cp _build/src/ofuzz.native $(OFUZZ_DISTDIR)/bin/ofuzz
	@cp _build/src/minimizer.native $(OFUZZ_DISTDIR)/bin/minimizer
	@cp -PR _build/ofuzz.docdir/ $(OFUZZ_DISTDIR)/docs/apis/
	@find $(OFUZZ_DISTDIR) -type l -exec rm -f {} \;
	@cp -PR docs/* $(OFUZZ_DISTDIR)/docs/
	@find $(OFUZZ_DISTDIR) -type l -exec rm -f {} \;
	@cp -PR src/ $(OFUZZ_DISTDIR)/src/
	@cp ReleaseNotes.md README.md AUTHOR $(OFUZZ_DISTDIR)/
	@cp ocaml-compatibility.sh Makefile Makefile.dep *.clib $(OFUZZ_DISTDIR)/
	@cp myocamlbuild.ml $(OFUZZ_DISTDIR)/
	@cp -R buildtools/ $(OFUZZ_DISTDIR)/buildtools/
	@cp -R conf/ $(OFUZZ_DISTDIR)/conf/
	@cp -R db/ $(OFUZZ_DISTDIR)/db/
	@cp -R triage/ $(OFUZZ_DISTDIR)/triage/
	@cp -R unittest/ $(OFUZZ_DISTDIR)/unittest/
	@cp -R utils/ $(OFUZZ_DISTDIR)/utils/
	@tar cfj ofuzz.$(DIST_VERSION).bz2 $(OFUZZ_DISTDIR)/
	@rm -rf $(OFUZZ_DISTDIR)

.PHONY: all clean depcheck version unittest doc dist
