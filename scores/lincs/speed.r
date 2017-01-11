library(dplyr)
b = import('base')
io = import('io')
ar = import('array')
df = import('data_frame')
lincs = import('data/lincs')

INFILE = commandArgs(TRUE)[1] %or% "../../model/model_linear.RData"
INDEX = commandArgs(TRUE)[2] %or% "../../util/lincs/index.RData"
OUTFILE = commandArgs(TRUE)[3] %or% "speed_linear.RData"

row2scores = function(i) {
    row = index[i,]
    sign = row$sign
    ptb = df$subset(exps, row)$distil_id

    row$pathway = "control"
    row$pert_id = "DMSO"
    row$pert_dose = NULL
    row$sign = "0"
    ctl = df$subset(exps, row)$distil_id

    expr_ctl = expr[ctl,,drop=FALSE]
    expr_ptb = expr[ptb,,drop=FALSE]

    if (sign == "+")
        colMeans(expr_ptb) - colMeans(expr_ctl)
    else
        colMeans(expr_ctl) - colMeans(expr_ptb)
}

# load model vectors and experiment index
vecs = io$load(INFILE)$model
exps = io$load(INDEX)
expr = lincs$get_z(exps$distil_id, rid=lincs$projected, map_genes="hgnc_symbol")

# get scores of experiments
ar$intersect(expr, vecs, along=1)
expr = t(expr) %*% vecs

index = exps %>%
    select(pathway, cell_id, pert_id, pert_dose, pert_time, sign) %>%
    filter(pathway != "control") %>%
    distinct()

scores = pbapply::pblapply(seq_len(nrow(index)), row2scores) %>%
    setNames(seq_len(nrow(index))) %>%
    ar$stack(along=1) %>%
    ar$map(along=1, scale)

save(scores, index, file=OUTFILE)
