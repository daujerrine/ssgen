EXECDIR := /usr/local/bin
DATADIR := /usr/share/ssgen

PERL := perl

install: ssgen.pl "t_dirindex.xhtml1.0t.html"
	mkdir $(DATADIR)
	cp "t_dirindex.xhtml1.0t.html" $(DATADIR)
	cp ssgen.pl $(EXECDIR)
	mv $(INSTALLDIR)/ssgen.pl $(EXECDIR)/ssgen
	chmod +x $(INSTALLDIR)/ssgen

uninstall: $(INSTALLDIR)/ssgen
	rm $(INSTALLDIR)/ssgen
	rm -r $(DATADIR)

test: ssgen.pl test/www/dummy test/src/a.sc test/src/b.tm
	$(PERL) ssgen.pl -c test.cfg

clean-test: test/www/a.html test/www/index.html
	rm test/www/a.html test/www/index.html
