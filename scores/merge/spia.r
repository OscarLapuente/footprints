b = import('base')
io = import('io')
hpc = import('hpc')

INFILE = commandArgs(TRUE)[1] %or% "../../genesets/reactome.RData"
EXPR = commandArgs(TRUE)[2] %or% "../../expr_cluster/corrected_expr.h5"
OUTFILE = commandArgs(TRUE)[3] %or% "spia.RData"

KEGG = list(
    MAPK = "04010", # MAPK signaling pathway
    EGFR = "04012", # ErbB signaling pathway
    PPAR = "03320", # PPAR signaling pathway
    PI3K = "04150", # mTOR signaling pathway
    Wnt = "04310", # Wnt signaling pathway
    Notch = "04330", # Notch signaling pathway
    Insulin = "04910", # Insulin signaling pathway
    NFkB = "04064", # NF-kappa B signaling pathway
    VEGF = "04370", # VEGF signaling pathway
    `JAK-STAT` = "04630", # Jak-STAT signaling pathway
    TGFB = "04350", # TGF-beta signaling pathway
    Trail = "04210" # Apoptosis
)

tissue2scores = function(tissue, lookup, EXPR, KEGG) {
    b = import('base')
    io = import('io')
    spia = import_package('SPIA')

    # prepare data
    tissues = io$h5load(EXPR, "/tissue")
    tumors = t(io$h5load(EXPR, "/expr", index=which(tissues == tissue)))
    normals = t(io$h5load(EXPR, "/expr", index=which(tissues == paste0(tissue, "_N"))))
    data = cbind(tumors, normals)
    types = c(rep("tumor", ncol(tumors)), rep("normal", ncol(normals)))

    # map IDs to entrez gene IDs, SPIA needs this
    rownames(data) = lookup$entrezgene[match(rownames(data), lookup$hgnc_symbol)]
    data = limma::avereps(data[!is.na(rownames(data)),])

    # compute differential expression between tumor and normal
    design = model.matrix(~ 0 + as.factor(types))
    colnames(design) = sub("as\\.factor\\(types\\)", "", colnames(design))
    contrast = limma::makeContrasts("tumor-normal", levels=design)
    fit = limma::lmFit(data, design) %>%
        limma::contrasts.fit(contrast) %>%
        limma::eBayes()
    result = dplyr::data_frame(gene = rownames(fit),
        p.value = fit$p.value[,1],
        fold_change = fit$coefficients[,1]) %>%
        mutate(adj.p = p.adjust(p.value, method="fdr"))

    # calculate SPIA scores (relevant fields: Name [KEGG name], ID [KEGG ID], tA [score])
    re = spia$spia(
        de = setNames(result$fold_change, result$gene)[result$adj.p < 0.05],
        all = result$gene,
        organism = "hsa",
        nB = 2000,
        plots = FALSE
    )
    re = re[re$ID %in% KEGG,]
    setNames(re$tA, re$Name)
}

# load pathway gene sets
genesets = io$load(INFILE)

# get all tissues which have a normal
tissues = io$h5load(EXPR, "/tissue")
tissues = sub("_N", "", unique(tissues[grepl("_N", tissues)]))

# HGNC -> entrez gene lookup
lookup = biomaRt::useMart(biomart="ensembl", dataset="hsapiens_gene_ensembl") %>%
    biomaRt::getBM(attributes=c("hgnc_symbol", "entrezgene"),
    filter="hgnc_symbol", values=io$h5names(EXPR, "/expr")[[2]], mart=.)

# run pathifier in jobs
result = hpc$Q(tissue2scores, tissue=tissues,
    more.args=list(EXPR=EXPR, KEGG=KEGG, lookup=lookup), memory=10240)

# save results
save(result, file=OUTFILE)
