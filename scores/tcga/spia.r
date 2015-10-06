b = import('base')
io = import('io')
ar = import('array')
hpc = import('hpc')

OUTFILE = commandArgs(TRUE)[1] %or% "spia.RData"

tissue2scores = function(tissue) {
    io = import('io')
    tcga = import('data/tcga')
    spia = import('../../util/spia')

    # convert hgnc to entrez
    expr = tcga$rna_seq(tissue)

    # HGNC -> entrez gene lookup
    lookup = biomaRt::useMart(biomart="ensembl", dataset="hsapiens_gene_ensembl") %>%
        biomaRt::getBM(attributes=c("hgnc_symbol", "entrezgene"),
        filter="hgnc_symbol", values=rownames(expr), mart=.)

    rownames(expr) = lookup$entrezgene[match(rownames(expr), lookup$hgnc_symbol)]
    expr = limma::avereps(expr[!is.na(rownames(expr)),])

    is_normal = grepl("[Nn]ormal", tcga$barcode2index(colnames(expr))$Sample.Definition)
    tumors = expr[,!is_normal]
    normals = expr[,is_normal]

    spia$spia(tumors, normals, per_sample=TRUE, pathids=spia$speed2kegg, verbose=TRUE)
}

# load pathway gene sets
tissues = c("BLCA", "BRCA", "CESC", "COREAD", "ESCA", "HNSC",
            "KIRC", "LIHC", "LUAD", "LUSC", "PAAD")

# run spia in jobs and save
result = hpc$Q(tissue2scores, tissue=tissues,
    memory=8192, n_jobs=length(tissues), log_worker=TRUE)

result = ar$stack(result, along=1)
colnames(result) = spia$kegg2speed[colnames(result)]

save(result, file=OUTFILE)
