INSTALLDIR := /usr/local/bin

install: ssgen.pl
	cp ssgen.pl $(INSTALLDIR)
	mv $(INSTALLDIR)/ssgen.pl $(INSTALLDIR)/ssgen
	chmod +x $(INSTALLDIR)/ssgen

uninstall: $(INSTALLDIR)/ssgen
	rm $(INSTALLDIR)/ssgen
