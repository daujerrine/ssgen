EXECDIR := /usr/local/bin
DATADIR := /usr/share/ssgen

install: ssgen.pl "t_dirindex.xhtml1.0t.html"
	mkdir $(DATADIR)
	cp "t_dirindex.xhtml1.0t.html" $(DATADIR)
	cp ssgen.pl $(EXECDIR)
	mv $(INSTALLDIR)/ssgen.pl $(EXECDIR)/ssgen
	chmod +x $(INSTALLDIR)/ssgen

uninstall: $(INSTALLDIR)/ssgen
	rm $(INSTALLDIR)/ssgen
	rm -r $(DATADIR)
