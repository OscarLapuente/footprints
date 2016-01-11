# get pathway scores and mutations, and correlate them with each other
b = import('base')
io = import('io')
st = import('stats')
ar = import('array')
plt = import('plot')
tcga = import('data/tcga')

subs2plots = function(subs, cna, scores) {
    message(subs)
    if (grepl("pan", subs)) {
        m = cna %>%
            group_by(hgnc) %>%
            filter(n() >= 50) %>%
            ungroup()
        size = 0.1
    } else {
        m = filter(cna, study==subs) %>%
            group_by(hgnc) %>%
            filter(n() >= 5) %>%
            ungroup()
        size = 0.5
    }

    num_sample = length(unique(m$sample))
    altered = m$hgnc
    m$altered = 1
    m = ar$construct(altered ~ sample + hgnc, data=m,
                     fun.aggregate = mean, fill=0)
    ar$intersect(m, scores)

    if (nrow(m) == 0) {
        warning("no overlap between mutations and scores for ", subs)
        return(NULL)
    }

    # associations
    if (grepl("cov", subs)) {
        study = tcga$barcode2study(rownames(scores))
        assocs = st$lm(scores ~ study + m)
    } else
        assocs = st$lm(scores ~ m)

    assocs %>%
        filter(term == "m") %>%
        select(-term) %>%
        mutate(adj.p = p.adjust(p.value, method="fdr"))

#    # matrix plot
#    p1 = result %>%
#        mutate(label = ifelse(adj.p < 0.01, "*", "")) %>%
#        plt$cluster(estimate ~ scores + m) %>%
#        filter(adj.p < 0.1) %>%
#        plt$matrix(estimate ~ scores + m, color="estimate") +
#            ggtitle(subs)
#    print(p1)

    # volcano plot
    result %>%
        mutate(label = paste(m, scores, sep=":")) %>%
        plt$color$p_effect(pvalue="adj.p", thresh=0.1) %>%
        plt$volcano(base.size=size, p=0.1) +
            ggtitle(paste0(subs, " (", num_sample, " samples, ",
                           length(altered), " CNAs in ",
                           length(unique(altered)), " genes)"))
}

INFILE = commandArgs(TRUE)[1] %or% "../../scores/tcga/speed_matrix.RData"
OUTFILE = commandArgs(TRUE)[2] %or% "cna_gistic.pdf"
CNAFILE = "cna.txt"

scores = io$load(INFILE)
rownames(scores) = substr(rownames(scores), 1, 15)
gistic_lookup = setNames(c("+", "-"), c(2, -2))

cna = io$read_table(CNAFILE, header=TRUE) %>%
    transmute(hgnc = GENE_NAME,
              sample = substr(Tumor_Sample_Barcode, 1, 15), # NO PORTION
              study = study,
              gistic = sapply(CNA_gistic, function(x) gistic_lookup[as.character(x)])) %>%
    mutate(hgnc = paste0(hgnc, gistic)) %>%
    select(-gistic) %>%
    filter(!study %in% c("KICH","LAML")) # no alteration present n>=cutoff

plots = cna$study %>%
    unique() %>%
    sort() %>%
    c("pan", "pan_cov", .) %>%
    lapply(function(s) subs2plots(s, cna, scores))

pdf(OUTFILE, paper="a4r", width=26, height=20)
for (plot in plots)
    print(plot)
dev.off()
