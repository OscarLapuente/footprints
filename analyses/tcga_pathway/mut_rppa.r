library(dplyr)
io = import('io')
ar = import('array')
df = import('data_frame')
st = import('stats')
icgc = import('data/icgc')
plt = import('plot')

speed_full = io$load('../../model/model_norm.RData')
avail = icgc$available(rna_seq=TRUE, mutations=TRUE)

STUDY = c("Breast_Invasive_Carcinoma-TCGA-US",
        # "Pancreatic_Cancer-QCMG-AU", # no normals
        # "Ovarian_Serous_Cystadenocarcinoma-TCGA-US", # no normals
          "Lung_Adenocarcinoma-TCGA-US",
          "Kidney_Renal_Clear_Cell_Carcinoma-TCGA-US",
          "Thyroid_Carcinoma-TCGA-US",
#        "Neuroblastoma-TARGET-US", # nothing avail
          "Uterine_Corpus_Endometrioid_Carcinoma-TCGA-US",
        # "Acute_Lymphoblastic_Leukemia-TARGET-US", # blood cancer, needs different fields
          "Colon_Adenocarcinoma-TCGA-US",
          "Lung_Squamous_Cell_Carcinoma-TCGA-US",
          "Head_and_Neck_Squamous_Cell_Carcinoma-TCGA-US")

pdf("plot.pdf", paper="a4r", width=26, height=20)
on.exit(dev.off())

for (cur_study in STUDY) {
    # get clinical + expression data
    cc = icgc$clinical() %>%
        filter(study == cur_study,
               specimen_type %in% c("Normal - tissue adjacent to primary",
#                                    "Normal - solid tissue",
                                    "Primary tumour - solid tissue"),
#               donor_sex == "female",
               icgc_specimen_id %in% avail) %>%
        select(icgc_donor_id, icgc_specimen_id, specimen_type, tissue)

    # compute speed scores for all
    speed = speed_full
    expr = na.omit(icgc$rna_seq(cc$icgc_specimen_id, voom=TRUE))
    ar$intersect(speed, expr, along=1)
    scores = t(expr) %*% speed
    scores = scores[cc$icgc_specimen_id,]
#    scores = scores %>% ar$map(along=1, function(x) {
#        normal = x[grepl("^Normal", cc$specimen_type)]
#        (x - median(normal)) / sd(normal)
#    })

    # get tcga mutation data
    mut = t(icgc$mutations(cc$icgc_specimen_id, minN=5))
    ar$intersect(scores, mut, along=1)

    # volcano plot of the pathway associations
    xx = st$lm(scores ~ mut) %>%
        plt$volcano()
}
