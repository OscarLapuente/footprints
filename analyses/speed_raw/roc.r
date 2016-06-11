library(cowplot)
library(dplyr)
library(reshape2)
b = import('base')
io = import('io')
ar = import('array')
st = import('stats')
config = import('../../config')

#' Return a data.frame with precision-recall curves
#'
#' @param fid  Method ID descriptor ('speed_matrix', 'gsea_go', etc.)
method2pr_df = function(fid) {
	data = io$load(module_file("../../scores/speed", paste0(fid, ".RData"), mustWork = TRUE))

	index = data$index # bit duplication from report/util_1 (4 lines w/ 2 above)
    sign = ifelse(index$effect == "activating", 1, -1)
	scores = data$scores * sign # not sure if col+row-scale here, but we look per-pathway

    df = data.frame(pathway=index$pathway, scores, check.names=FALSE) %>%
        melt(id="pathway") %>%
        mutate(perturbed = as.integer(variable==pathway),
               method = fid) %>%
        select(-variable) %>%
        na.omit() %>%
        group_by(pathway) %>%
        do(st$roc(., "value", "perturbed")) %>%
        ungroup()
}

do_plot = function(roc, width=1) {
    random_line = data.frame(x=c(0,1), y=c(0,1), method=roc$method[1])

    ggplot(roc, aes(x=FPR, y=TPR, color=method)) +
        geom_line(aes(x=x, y=y), data=random_line, color="grey", linetype="dashed") +
        geom_step(size=width) +
        coord_fixed() +
        facet_wrap(~pathway) +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

roc = config$methods$ids %>%
    setdiff("paradigm") %>% # we don't have this for the input exps
    lapply(method2pr_df) %>%
    bind_rows() %>%
    na.omit()

auc = roc %>%
    mutate(method = config$id2short(method)) %>%
    group_by(method, pathway) %>%
    arrange(value) %>%
    summarize(auc = st$roc_auc(value, perturbed==1)) %>%
    tidyr::spread(method, auc)

if (is.null(module_name())) {
    pdf("roc.pdf", paper="a4r", width=11, height=8)

    print(do_plot(roc))

    dev.off()
}
