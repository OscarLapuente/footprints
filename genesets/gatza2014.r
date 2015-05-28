b = import('base')
ar = import('array')

# could include AKT here, but which pathway does it fit?
# or I need a SPEED-Akt signature to compare
gatza2014 = list(
#      "IL-1" = "",
      "JAK-STAT" = c("STAT1", "STAT3", "IFNA", "IFNG"),
      "MAPK" = c("PROLIFERATION", "PROLIFERATION (PAM50)"), # AKT, MYC don't really fit
      "EGFR" = "EGFR",
      "PI3K" = c("PI3K", "PIK3CA"),
      "TGFb" = "TGFB",
      "TNFa" = "TNFA",
      "VEGF" = "VEGF/HYPOXIA",
      "Wnt" = "BETA CATENIN",
#      "Insulin" = "",
      "Hypoxia" = "HYPOXIA",
#      "RAR" = "",
      "p53" = c("P53", "P53 MUT/P53 WT CORR"),
      "Estrogen" = c("ER", "E2 ACTIVATED (IE) / E2 REPRESSED CORR")#,
#      "Trail" = "",
#      "notch" = "",
#      "NFkB" = "",
#      "PPAR" = "",
#      "SHH" = ""
)

INFILE = commandArgs(TRUE)[1] %or% 'ng.3073-S2.csv'

df = read.csv('ng.3073-S2.csv', row.names=NULL, check.names=FALSE)
lists = lapply(ar$split(as.matrix(df), 2, drop=TRUE), b$omit$empty)

save(lists, file = commandArgs(TRUE)[2] %or% 'gatza.RData')
