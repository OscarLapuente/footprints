b = import('base')
io = import('io')
ar = import('array')
df = import('data_frame')
tcga = import('data/tcga')
genesets = import('../../util/genesets')

INFILE = commandArgs(TRUE)[1] %or% "../../util/genesets/mapped/reactome.RData"
OUTFILE = commandArgs(TRUE)[2] %or% "pathways_mapped/pathifier.RData"
TISSUES = import('../../config')$tcga$tissues_with_normals

if (grepl("mapped", OUTFILE)) {
    MIN_GENES = 1
    MAX_GENES = Inf
    job_size = 5
} else {
    MIN_GENES = 5
    MAX_GENES = 500
    job_size = 25
}

#' Calculates Pathifier scores for one tissue vs all others
#'
#' @param tissue    The tissue to calculate scores for
#' @param expr      An expression matrix with [genes x samples]
#' @param genesets  A list of character vectors corresponding to
#'                  gene sets (e.g. pathways for pathway scores)
tissue2scores = function(tissue, genesets, expr) {
    library(dplyr)
    io = import('io')
    tcga = import('data/tcga')
    pathifier = import_package('pathifier')

    index = tcga$barcode2index(colnames(expr)) %>%
        filter(Study.Abbreviation == tissue)
    my_expr = expr[,index$Bio.ID]
    is_normal = grepl("[Nn]ormal", index$Sample.Definition)

    result = pathifier$quantify_pathways_deregulation(
        data = my_expr,
        allgenes = rownames(my_expr),
        syms = genesets,
        pathwaynames = names(genesets),
        normals = is_normal,
#        attempts = 100, # default settings
        min_exp = -Inf, #TODO: std=4, applicable to voom?
#        min_std = 0.4
    )

    re = do.call(cbind, lapply(result$scores, c))
    rownames(re) = colnames(my_expr)
    re
}

# load pathway gene sets
expr = tcga$rna_seq(TISSUES)
genesets = io$load(INFILE) %>%
    genesets$filter(rownames(expr), MIN_GENES, MAX_GENES)

# make compatible to call with one set in above function
for (i in seq_along(genesets))
    genesets[[i]] = setNames(list(genesets[[i]]), names(genesets)[i])

# run pathifier in jobs
hpc_args = list(memory=10240, job_size=job_size, n_jobs=300, fail_on_error=FALSE)

result = b$expand_grid(tissue=TISSUES, genesets=genesets) %>%
    df$call(tissue2scores, expr = expr, result_only=TRUE, hpc_args=hpc_args)

result[sapply(result, class) == "try-error"] = NULL
result = ar$stack(result, along=2)

# save results
save(result, file=OUTFILE)
