PLUGINPATH = ../../lib/coq_verified_extraction_plugin/_build/install/default/lib:../../lib/coq_verified_extraction_ocaml_ffi/_build/install/default/lib

all: plugin

Makefile.coq: _CoqProject
	coq_makefile -f _CoqProject -o Makefile.coq

plugin: Makefile.coq
	mkdir -p -m 0755 _build
	OCAMLPATH=$(PLUGINPATH) $(MAKE) -f Makefile.coq

install: plugin
	$(MAKE) -f Makefile.coq install
	
uninstall: Makefile.coq
	$(MAKE) -f Makefile.coq uninstall
	
clean: Makefile.coq
	make -f Makefile.coq clean

mrproper:
	rm -f Makefile.coq

.merlin: Makefile.coq
	make -f $< $@

cleanplugin: Makefile.coq
	make -f Makefile.coq clean
