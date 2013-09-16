LATEX = latex
DVIPS = dvips
PS2PDF = ps2pdf
MD2TEX = tools/md2tex
BREAK = tools/break-after-colon-in-title-slides
INSERT = tools/insert-into-template
PERL = perl
PANDOC = pandoc

all: output/slides-day1.pdf output/slides-day2.pdf
exercises : output/exercises.pdf
handouts: output/handouts.pdf

output/slides-day1.pdf : output/slides-day1.tex eps/*
	$(LATEX) -output-directory=output output/slides-day1.tex
	$(DVIPS) output/slides-day1.dvi -o output/slides-day1.ps
	$(PS2PDF) output/slides-day1.ps output/slides-day1.pdf

output/slides-day1.tex : src/slides-day1.md $(MD2TEX)
	$(PERL) $(MD2TEX) src/slides-day1.md output/slides-day1.tex
	$(PERL) -pi.bak -e "s/\(FIXUP\)//g" output/slides-day1.tex
	$(PERL) -i.bak $(BREAK) output/slides-day1.tex

output/slides-day2.pdf : output/slides-day2.tex eps/*
	$(LATEX) -output-directory=output output/slides-day2.tex
	$(DVIPS) output/slides-day2.dvi -o output/slides-day2.ps
	$(PS2PDF) output/slides-day2.ps output/slides-day2.pdf

output/slides-day2.tex : src/slides-day2.md $(MD2TEX)
	$(PERL) $(MD2TEX) src/slides-day2.md output/slides-day2.tex
	$(PERL) -pi.bak -e "s/\(FIXUP\)//g" output/slides-day2.tex
	$(PERL) -i.bak $(BREAK) output/slides-day2.tex

output/exercises.pdf : src/exercises.md src/template-exercises.tex
	$(PANDOC) src/exercises.md -f markdown -t latex > output/exercises-body.tex
	$(PERL) -pi.bak -e 's/\\section/\\section*/' output/exercises-body.tex
	$(PERL) -pi.bak -e 's/\\subsection/\\subsection*/' output/exercises-body.tex
	$(PERL) $(INSERT) output/exercises-body.tex > output/exercises.tex
	$(LATEX) -output-directory=output output/exercises.tex
	$(DVIPS) output/exercises.dvi -o output/exercises.ps
	$(PS2PDF) output/exercises.ps output/exercises.pdf

output/handouts.pdf : src/handouts.tex output/slides-day1.pdf output/slides-day2.pdf
	$(LATEX) -output-directory=output -output-format=pdf src/handouts.tex
