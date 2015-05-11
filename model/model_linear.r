# point of this file:
# - use the zscores to create a linear model

io = import('io')
ar = import('array')
st = import('stats')
gdsc = import('data/gdsc')
plt = import('plot')

# load speed data, index
expr = io$load('../data/zscores.RData')
zscores = expr$zscores
index = expr$index
#TODO: inhibiting zscores = -1*zscores (or leave them out for now)

# fit model to pathway perturbations
mod = st$lm(zscores~0+pathway, data=index)
zfit = lm$selectFeatures(zfit, min=pval, n=100)
