TCGA_SCORES = $(wildcard ../../scores/tcga/*.RData)
SURV = $(TCGA_SCORES:../../scores/tcga/%.RData=%.pdf)

all: prereqs $(SURV)

prereqs:
	make -C ../../scores/tcga

%.pdf: ../../scores/tcga/%.RData survival.r
	Rscript survival.r $< $@