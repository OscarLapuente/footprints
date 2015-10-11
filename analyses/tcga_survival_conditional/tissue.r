library(dplyr)
b = import('base')
io = import('io')
ar = import('array')
df = import('data_frame')
st = import('stats')
plt = import('plot')
tcga = import('data/tcga')

scores2assocs = function(scores, clinical, fdr=0.1) {
    # make sure we only use primary tumors with one sample
    cc = clinical[!duplicated(clinical$barcode),]
    rownames(cc) = cc$barcode
    ar$intersect(scores, cc, along=1)
    cc = as.list(cc)
    cc$scores = scores #TODO: this should not be required

    # separate regressions for each tissue
    #TODO: add gender + make it work w/ only one
    assocs = st$coxph(surv_days + alive ~ age_days + scores, subsets=cc$study, data=cc, min_pts=20) %>%
        filter(term == "scores") %>%
        select(scores, subset, estimate, p.value, size) %>%
        group_by(subset) %>%
        mutate(adj.p = p.adjust(p.value, method="fdr")) %>%
        ungroup()
    message(sum(assocs$adj.p < fdr), " significant associations, FDR: ", fdr)
    assocs
}

conditional_assocs = function(scores, clinical, condition, fdr=0.1) {
    # make sure we only use primary tumors with one sample
    cc = clinical[!duplicated(clinical$barcode),]
    rownames(cc) = cc$barcode
    ar$intersect(scores, condition, cc, along=1)

    best_speed_hit = a_speed %>%
        group_by(scores, subset) %>%
        filter(adj.p == min(adj.p)) %>%
        select(scores, subset, adj.p)

    cmat = ar$like(NA, scores)
    for (i in 1:nrow(best_speed_hit)) {
        cur = best_speed_hit[i,]
        if (! cur$scores %in% colnames(scores))
            next
        cmat[cc$study == cur$subset, cur$scores] =
            condition[cc$study == cur$subset, cur$scores]
    }

    # return df with associations still significant after conditioning
    st$coxph(surv_days + alive ~ age_days + cmat + scores,
             subsets=cc$study, data=cc, min_pts=20, group=c("scores","cmat")) %>%
        filter(term == "scores") %>%
        select(scores, subset, estimate, p.value, size) %>%
        group_by(subset) %>%
        mutate(adj.p = p.adjust(p.value, method="fdr")) %>%
        ungroup() %>%
        filter(adj.p < fdr)
}

assocs2plot = function(assocs, title="", ylim=c(NA,NA), fdr=0.1, condition=NULL) {
    assocs = assocs %>%
        mutate(label = paste(subset, scores, sep=":")) %>%
        plt$color$p_effect(pvalue="adj.p", effect="estimate", dir=-1, thresh=fdr)

    if (!is.null(condition)) {
        subset_valid = condition %>%
            select(subset, scores) %>%
            df$contains(assocs, .) %catch% FALSE

        assocs[!subset_valid & assocs$adj.p < fdr,'color'] = "#00000000"
        assocs[!subset_valid & assocs$adj.p < fdr,'circle'] = "#767676ff"
    }

    assocs %>%
        plt$volcano(base.size=0.2, p=fdr,
            ylim=c(1,1e-7), xlim=c(-0.8,0.8)) + ggtitle(title)
}


clinical = tcga$clinical() %>%
    transmute(study = study,
              age_days = - as.integer(patient.days_to_birth),
              alive = 1 - as.integer(is.na(patient.days_to_death)),
              surv_days = as.integer(patient.days_to_death %or%
                                     patient.days_to_last_followup),
              barcode = toupper(patient.bcr_patient_barcode),
              gender = as.factor(patient.gender)) %>%
    filter(surv_days > 0) %>% #FIXME: why is there 0 survival days?
    filter(study %in% c("BLCA", "BRCA", "CESC", "ESCA", "HNSC", "COAD",
            "KIRC", "LIHC", "LUAD", "LUSC", "PAAD")
)

# load scores; s_: prefix for scores
load_scores = function(fname) {
    re = io$load(fname)
    re = re[substr(rownames(re), 14, 16) == "01A",]
    rownames(re) = substr(rownames(re), 1, 12)
    ar$map(re, along=1, function(x) x/sd(x))
}
s_speed = load_scores('../../scores/tcga/speed_matrix.RData')
s_reac = load_scores('../../scores/tcga/gsea_reactome.RData')
s_go = load_scores('../../scores/tcga/gsea_go.RData')
s_spia = load_scores('../../scores/tcga/spia.RData')
s_pathifier = load_scores('../../scores/tcga/pathifier.RData')

# a_: prefix for associations
a_speed = scores2assocs(s_speed, clinical, 0.1) #
a_reac = scores2assocs(s_reac, clinical, 0.1) # 0.2: , 0.1:
a_go = scores2assocs(s_go, clinical, 0.1) # 
a_spia = scores2assocs(s_spia, clinical, 0.1)
a_pathifier = scores2assocs(s_pathifier, clinical, 0.1)

# c_: prefix conditional associations
c_reac = conditional_assocs(s_reac, clinical, condition=s_speed)
c_go = conditional_assocs(s_go, clinical, condition=s_speed)
c_spia = conditional_assocs(s_spia, clinical, condition=s_speed)
c_pathifier = conditional_assocs(s_pathifier, clinical, condition=s_speed)

# v_: prefix for volcano plots
v_speed = assocs2plot(a_speed, "speed") # limit are there so axes are equal
v_reac = assocs2plot(a_reac, "reactome", condition=c_reac)
v_go = assocs2plot(a_go, "GO", condition=c_go)
v_spia = assocs2plot(a_spia, "spia", condition=c_spia)
v_pathifier = assocs2plot(a_pathifier, "pathifier", condition=c_pathifier)

# arrange plots
pcol = arrangeGrob(v_speed, v_spia, v_reac, v_pathifier, v_go, ncol=2, nrow=3)

# save to pdf
pdf("tissue.pdf", width=12, height=15)
plot(pcol)
dev.off()
