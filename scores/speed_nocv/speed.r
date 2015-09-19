library(dplyr)
b = import('base')
io = import('io')
ar = import('array')

INFILE = commandArgs(TRUE)[1] %or% "../../model/model_linear.RData"
OUTFILE = commandArgs(TRUE)[2] %or% "speed_linear.RData"

# load vectors
vecs = io$load(INFILE)

# calculate scores from expr and speed vectors
speed = io$load('../../data/expr.RData')
index = speed$records
expr = speed$expr

# scaling: assume mean/sd across scores per sample is constant
# this protects against missing genes, etc in platform
expr2scores = function(index, expr, vecs) {
    ar$intersect(vecs, expr, along=1)
    t(expr) %*% vecs %>%
        ar$map(along=1, scale) %>%
        ar$map(along=1, function(x) mean(x[index$perturbed]) - mean(x[index$control]))
}

scores = mapply(expr2scores, index=index, expr=expr,
    MoreArgs=list(vecs=vecs), SIMPLIFY=FALSE) %>%
    ar$stack(along=1)

filter_index = function(x) x[! names(x) %in% c('control', 'perturbed', 'exclusion')]
index = lapply(index, filter_index) %>%
    bind_rows()

save(scores, index, file=OUTFILE)
