library(dplyr)
library(gridExtra)
library(corrplot)
b = import('base')
io = import('io')
ar = import('array')
st = import('stats')
plt = import('plot')
tcga = import('data/tcga')

#' Takes a method subset and plots the pathway associations and individual scores
#'
#' @param fid  A file identifer, e.g. 'speed_matrix' or 'gsea_reactome'
#' @return     A ggplot matrix plot and heatmap in one line
perturb_score_plots = function(fid) {
    data = io$file_path("../scores/speed", fid, ext=".RData") %>%
        io$load()

	index = data$index
	scores = data$scores
	sign = ifelse(index$effect == "activating", 1, -1)
	pathway = sign * ar$mask(index$pathway) + 0

	# the associations per pathway
	result = st$lm(scores ~ pathway) %>%
		mutate(mlogp = -log(p.value)) %>%
		mutate(label = ifelse(p.value < 1e-5, "*", "")) %>%
		mutate(label = ifelse(p.value < 1e-10, "***", label))

	p1 = plt$matrix(result, statistic ~ scores + pathway, palette="RdBu", symmetric=TRUE) +
		xlab("Pathway perturbed") +
		ylab("Assigned score")

	# and individual experiments
	annot = data$index %>%
		select(id, pathway, effect) %>%
		arrange(pathway, effect) %>%
		as.data.frame()

	scores = data$scores[annot$id,]
	scores[annot$effect == "inhibiting"] = - scores[annot$effect == "inhibiting"]
	scores = t(scores)
	rownames(scores) = substr(rownames(scores), 0, 40)

	# remove id column, add names for pheatmap to understand
	rownames(annot) = annot$id
	annot$id = NULL

	p2 = pheatmap::pheatmap(scores,
                            annotation = annot,
                            scale = "column",
                            cluster_cols = FALSE,
                            show_colnames = FALSE,
                            annotation_legend = FALSE,
                            treeheight_row = 20,
                            legend = FALSE,
                            cellwidth = 0.3, silent=TRUE)

    grid.arrange(p1, p2$gtable, ncol=2)
}

cor_plots = function(fid) {
    gdsc = io$file_path("../scores/gdsc/pathways_mapped", fid, ext=".RData") %>% io$load()
    tcga_all = io$file_path("../scores/tcga/pathways_mapped", fid, ext=".RData") %>% io$load()

	index = tcga$barcode2index(rownames(tcga_all)) %>%
		filter(grepl("Primary|Normal", Sample.Definition), Vial == "A") %>%
		mutate(type = ifelse(grepl("Normal", Sample.Definition), "normal", "tumor"))

        cex.before = par("cex")
        par(cex = 0.5)

#        corrplot(cor(tcga_all[index$type == "normal",]), title="normal")
#        corrplot(cor(tcga_all[index$type == "tumor",]), title="tumor")
        corrplot(cor(tcga_all), title="tcga")
        corrplot(cor(gdsc), title="cell line")

        par(cex = cex.before)
}
