b = import('base')
io = import('io')
ar = import('array')
df = import('data_frame')
spia = import('../../util/spia')
tcga = import('data/tcga')

OUTFILE = commandArgs(TRUE)[1] %or% "pathways_mapped/spia.RData"
FILTER = as.logical(commandArgs(TRUE)[2]) #%or% TRUE
TISSUES = import('../../config')$tcga$tissues_with_normals

# handle COAD and READ separately
if ("COADREAD" %in% TISSUES)
    TISSUES = c(setdiff(TISSUES, "COADREAD"), "COAD", "READ")

if (FILTER) {
    pathids = spia$speed2kegg
} else {
    pathids = spia$pathids("hsa")
}

#' Calculates SPIA scores for a sample and pathway vs all tissue-normals
#'
#' @param sample   A character ID of the sample to compute scores for
#' @param expr     An expression matrix with [genes x samples]
#' @param pathids  A list of character vectors corresponding to
#'                 gene sets (e.g. pathways for pathway scores)
sample2scores = function(sample, expr, pathids=NULL) {
    library(magrittr)
    tcga = import('data/tcga')
    spia = import('../../util/spia')

    sample_tissue = tcga$barcode2study(sample)
    tissue_normals = tcga$barcode2index(colnames(expr)) %>%
        dplyr::filter(Study.Abbreviation == sample_tissue &
                      grepl("[Nn]ormal", Sample.Definition)) %$%
        Bio.ID

    stopifnot(length(tissue_normals) > 0)
    spia$spia(sample, tissue_normals, data=expr, pathids=pathids)
}

# load pathway gene sets
expr = tcga$rna_seq(TISSUES) %>%
    spia$map_entrez()

# run spia in jobs and save
hpc_args = list(memory=10240, job_size=1000, n_jobs=200, fail_on_error=FALSE)

result = b$expand_grid(sample = colnames(expr), pathids = pathids) %>%
    df$call(sample2scores, expr = expr, hpc_args=hpc_args)

result = ar$construct(result ~ sample + pathids, result)

if (FILTER)
    colnames(result) = spia$kegg2speed[colnames(result)]

save(result, file=OUTFILE)
