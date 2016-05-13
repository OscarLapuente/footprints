library(dplyr)
b = import('base')
ar = import('array')

OUTFILE = commandArgs(TRUE)[1] %or% "pathways_mapped/paradigm.RData"

pathways = c(
    p53 = "^response to DNA damage stimulus \\(abstract\\)",
    `JAK-STAT` = "^STAT1-3-5-active",
    Hypoxia = "^response to hypoxia \\(abstract\\)",
    VEGF = "^platelet-derived growth factor receptor activity \\(abstract\\)",
    Trail = "^induction of apoptosis \\(abstract\\)",
#    H2O2 = "^response to hydrogen peroxide \\(abstract\\)",
    EGFR = "^epidermal growth factor receptor activity \\(abstract\\)",
    MAPK = "^MEK1-2-active",
    PI3K = "^PIK3CA",
    TNFa = "^tumor necrosis factor receptor activity \\(abstract\\)",
    TGFb = "^SMAD1-5-8-active"
)

files = list.files("paradigm/path", "[0-9]+\\.txt", full.names=TRUE)

file2pathways = function(fname) {
    content = readLines(fname)

    grep_fun = function(x) grep(x, content, value=TRUE)
    num_fun = function(x) mean(as.numeric(sub("^[^\t]+\t", "", x)))

    paths = sapply(pathways, grep_fun)
    nums = sapply(paths, num_fun)
}

scores = lapply(files, file2pathways) %>%
    setNames(sub("\\.txt", "", basename(files))) %>%
    ar$stack(along=1)

save(scores, file=OUTFILE)
