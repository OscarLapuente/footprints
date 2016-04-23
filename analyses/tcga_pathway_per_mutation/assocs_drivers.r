# get pathway scores and mutations, and correlate them with each other
b = import('base')
io = import('io')
st = import('stats')
ar = import('array')
plt = import('plot')
tcga = import('data/tcga')

subs2assocs = function(subs, mut, scores) {
    gdsc = import('data/gdsc')

    message(subs)
    if (grepl("pan", subs)) {
        size = 0.5
        drivers = unique(gdsc$drivers()$HGNC)
        m = filter(mut, Hugo_Symbol %in% drivers)
    } else {
        size = 5
        drivers = unique(gdsc$drivers(subs)$HGNC)
        m = filter(mut, study==subs & Hugo_Symbol %in% drivers)
    }

    num_sample = length(unique(m$sample))
    altered = m$hgnc
    m$mut = 1
    m = ar$construct(mut ~ Tumor_Sample_Barcode + Hugo_Symbol,
                     data=m, fun.aggregate = length) > 0
    ar$intersect(m, scores)

    if (grepl("cov", subs)) {
        study = tcga$barcode2study(rownames(scores))
        assocs = st$lm(scores ~ study + m)
    } else {
        assocs = st$lm(scores ~ m)
    }

    result = assocs %>%
        filter(term == "mTRUE") %>%
        select(-term) %>%
        mutate(adj.p = p.adjust(p.value, method="fdr")) %>%
        mutate(label = paste(m, scores, sep=":"))
}

INFILE = commandArgs(TRUE)[1] %or% "../../scores/tcga/pathways_mapped/speed_matrix.RData"
OUTFILE = commandArgs(TRUE)[2] %or% "snp_drivers.pdf"

studies = import('../../config')$tcga$tissues

scores = io$load(INFILE)
rownames(scores) = substr(rownames(scores), 1, 16)

# AAChange is not avail in eg. BRCA (and others)
mut = tcga$mutations() %>%
    filter(Study %in% studies) %>%
    mutate(Tumor_Sample_Barcode = substr(Tumor_Sample_Barcode, 1, 16)) %>%
    filter(Tumor_Sample_Barcode %in% rownames(scores) & Variant_Classification != "Silent")

print(table(mut$Study))

assocs = mut$Study %>%
    unique() %>%
    sort() %>%
    c("pan", "pan_cov", .) %>%
    sapply(function(subs) subs2assocs(subs, mut, scores), simplify=FALSE, USE.NAMES=TRUE)

save(assocs, file=OUTFILE)
