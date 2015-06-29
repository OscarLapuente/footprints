# point of this file:
# - use the zscores to create a linear model
library(dplyr)
b = import('base')
io = import('io')
ar = import('array')
st = import('stats')

INFILE = commandArgs(TRUE)[1] %or% "../data/zscores.RData"
OUTFILE = commandArgs(TRUE)[2] %or% "model_norm.RData"

# load speed data, index
zobj = io$load('../data/zscores.RData')
zscores = zobj$scores
index = zobj$index

# adjust object for linear modelling
inh = index$effect=="inhibiting"
zscores[,inh] = -zscores[,inh]
zscores = ar$map(zscores, along=1, scale)
zscores = t(zscores)

# fit model to pathway perturbations
index = c(as.list(index), list(zscores=zscores)) #FIXME: @st$lm: use parent.frame()+provided df
mod = st$lm(zscores ~ 0 + pathway, data=index, min_pts=100) %>%
    transmute(gene = zscores,
              pathway = sub("^pathway", "", term),
              zscore = estimate,
              p.value = p.value) %>%
    group_by(gene) %>%
    mutate(p.adj = p.adjust(p.value, method="fdr")) %>%
    ungroup()

zfit = ar$construct(zscore ~ gene + pathway, data=mod)
pval = ar$construct(p.adj ~ gene + pathway, data=mod)

# filter zfit to only include top 100 genes per pathway
zfit[apply(pval, 2, p -> !b$min_mask(p, 100))] = 0

# save resulting object
save(zfit, file=OUTFILE)
