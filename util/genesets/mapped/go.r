library(biomaRt)
library(modules)
library(dplyr)
b = import('base')

OUTFILE = commandArgs(TRUE)[1] %or% "go.RData"

GO = list(#"H2O2" = "GO:0042542", # response to hydrogen peroxide
#    "IL-1" = "GO:0070498", # interleukin-1-mediated signalling pathway
    "JAK-STAT" = "GO:0007259", # JAK-STAT signal transduction
    "MAPK" = "GO:0000165", # MAPK cascade
    "EGFR" = "GO:0038127", # ERBB signaling pathway
#    "TLR" = "GO:0002224", # toll-like receptor signaling pathway
    "PI3K" = "GO:0014065", # phosphatidylinositol 3-kinase signaling
    "TGFb" = "GO:0007179", # transforming growth factor beta receptor signaling pathway
    "TNFa" = "GO:0033209", # tumor necrosis factor-mediated signaling pathway
    "VEGF" = "GO:0038084", # vascular endothelial growth factor signaling pathway
#    "Wnt" = "GO:0016055", # Wnt signaling pathway
#    "Insulin" = "GO:0008286", # insulin receptor signaling pathway
    "Hypoxia" = "GO:0071456", # cellular response to hypoxia
#    "RAR" = "GO:0048384", # retinoic acid receptor signaling pathway
    "p53" = "GO:0030330", # DNA damage response, signal transduction by p53 class mediator
#    "Estrogen" = "GO:0030520", # intracellular estrogen receptor signaling pathway
    "Trail" = "GO:0036462", # TRAIL-activated apoptotic signaling pathway
#    "notch" = "GO:0007219", # Notch signaling pathway
    "NFkB" = "GO:0038061")#, # NIK/NF-kappaB signaling
#    "PPAR" = "GO:0035357") # peroxisome proliferator activated receptor signaling pathway

# 319k x2 for all genes, 20k x2 for landmarks
mart = biomaRt::useMart(biomart="ensembl", dataset="hsapiens_gene_ensembl")

mapGO = biomaRt::getBM(attributes=c("hgnc_symbol", "go_id", "name_1006"),
    filter="go_id", values=unname(GO), mart=mart)

stacked = mapGO %>%
    filter(go_id != "") %>%
#    mutate(go=paste(go_id,name_1006)) %>%
    select(hgnc_symbol,go_id)

genesets = unstack(stacked)

# if mapping to SPEED pathways
pathways = sapply(names(GO), function(path) {
    unique(unlist(genesets[GO[[path]]]))
})

save(pathways, file=OUTFILE)
