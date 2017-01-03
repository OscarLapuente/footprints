library(dplyr)
b = import('base')
io = import('io')
ar = import('array')

INFILE = commandArgs(TRUE)[1] %or% "../../model/model_linear.RData"
OUTFILE = commandArgs(TRUE)[2] %or% "speed_linear.RData"

# load vectors
vecs = io$load(INFILE)$model

# calculate scores from expr and speed vectors
speed = io$load('../../data/expr.RData')
index = speed$records
expr = speed$expr

# scaling: assume mean/sd across scores per sample is constant
# this protects against missing genes, etc in platform
expr2scores = function(index, expr, vecs) {
    ar$intersect(vecs, expr, along=1)
    mat = t(expr) %*% vecs
    ctl = mat[index$control,,drop=FALSE]
    ptb = mat[index$perturbed,,drop=FALSE]
    (colMeans(ptb) - colMeans(ctl)) #/ ar$map(ctl, along=1, sd)
}

scores = mapply(expr2scores, index=index, expr=expr,
    MoreArgs=list(vecs=vecs), SIMPLIFY=FALSE) %>%
    ar$stack(along=1) %>%
    ar$map(along=1, scale)

filter_index = function(x) x[! names(x) %in% c('control', 'perturbed', 'exclusion')]
index = do.call(bind_rows, lapply(index, filter_index))

save(scores, index, file=OUTFILE)
