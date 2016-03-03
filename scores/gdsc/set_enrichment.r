b = import('base')
io = import('io')
ar = import('array')
gdsc = import('data/gdsc')
gsea = import('../../util/gsea')
hpc = import('hpc')

INFILE = commandArgs(TRUE)[1] %or% "../../util/genesets/mapped/go.RData"
OUTFILE = commandArgs(TRUE)[2] %or% "pathways_mapped/gsea_go.RData"
MIN_GENES = 5
MAX_GENES = 500

# load gene list and expression
expr = gdsc$basal_expression()
genelist = io$load(INFILE) %>%
    gsea$filter_genesets(rownames(expr), MIN_GENES, MAX_GENES)

# perform GSEA for each sample and signature
result = hpc$Q(gsea$runGSEA, sigs=genelist,
               const = list(expr=expr, transform.normal=TRUE),
               memory = 4096, job_size = 50)

# assemble results
result = setNames(result, names(genelist)) %>%
    ar$stack(along=2)

save(result, file=OUTFILE)
