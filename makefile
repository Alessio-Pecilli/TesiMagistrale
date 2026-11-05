finalname = main

included_latex_sources = \
	ringraziamenti.tex \
	introduzione.tex \
	1.tex \
	2.tex \
	3.tex \
	4.tex \
	5.tex \
	6.tex \
	7.tex \
	conclusioni.tex

$(finalname): $(included_latex_sources) bibliografia.bib $(finalname).tex
	pdflatex $(finalname).tex
	bibtex $(finalname)
	pdflatex $(finalname).tex
	pdflatex $(finalname).tex

clean:
	rm -f $(finalname).pdf
	rm -f $(finalname).log
	rm -f $(finalname).out
	rm -f $(finalname).toc
	rm -f $(finalname).aux
	rm -f $(finalname).bbl
	rm -f $(finalname).blg
	rm -f *.aux
