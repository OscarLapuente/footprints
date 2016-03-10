# get pathway scores and mutations, and correlate them with each other
b = import('base')
io = import('io')
st = import('stats')
ar = import('array')
plt = import('plot')
tcga = import('data/tcga')

subs2assocs = function(subs, mut, scores) {
    message(subs)
    if (grepl("pan", subs)) {
        m = mut
        size = 0.5
    } else {
        m = filter(mut, study==subs) %>%
            group_by(hgnc) %>%
            filter(n() >= 5) %>%
            ungroup()
        size = 5
    }

    num_sample = length(unique(m$sample))
    altered = m$hgnc
    m$mut = 1
    m = ar$construct(mut ~ sample + hgnc,
                     data=m, fun.aggregate = length) > 0
    ar$intersect(m, scores)

    if (nrow(m) == 0) {
        warning("no overlap between mutations and scores for ", subs)
        return(NULL)
    }

    if (grepl("cov", subs)) {
        study = tcga$barcode2study(rownames(scores))
        assocs = st$lm(scores ~ study + m)
    } else
        assocs = st$lm(scores ~ m)

    result = assocs %>%
        filter(term == "mTRUE") %>%
        select(-term) %>%
        mutate(adj.p = p.adjust(p.value, method="fdr")) %>%
        mutate(label = paste(m, scores, sep=":"))
}

INFILE = commandArgs(TRUE)[1] %or% "../../scores/tcga/speed_matrix.RData"
OUTFILE = commandArgs(TRUE)[2] %or% "snp_drivers.pdf"
MUTFILE = "mutations_annotated_pathwayactivities_v3_mikeformat.txt"

scores = io$load(INFILE)
rownames(scores) = substr(rownames(scores), 1, 16)

mut = io$read_table(MUTFILE, header=TRUE) %>%
    transmute(hgnc = GENE_NAME,
              sample = substr(Tumor_Sample_Barcode, 1, 16),
              study = tcga$barcode2study(Tumor_Sample_Barcode)) %>%
    filter(!is.na(study) & study != "READ")

assocs = mut$study %>%
    unique() %>%
    sort() %>%
    c("pan", "pan_cov", .) %>%
    lapply(function(s) subs2assocs(s, mut, scores))

save(assocs, file=OUTFILE)
