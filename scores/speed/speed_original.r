library(dplyr)
b = import('base')
io = import('io')
ar = import('array')
fdr_genes = import('../../analyses/signature_similarity/fdr_de')

#' Construct a data.frame for gene background using z and e filter
#'
#' @param idx      Metadata for each perturbation experiment
#' @param exp      Expression matrix
#' @param zscores  List of z-scores
#' @param z        Absolute z-score in order to be included
#' @param e        Absolute expression in order to be included
exp2background = function(idx, exp, zscores, z=0.01, e=0.5) {
    message(idx$id)

    ptb_mean_expr = narray::map(exp[,idx$perturbed], along=2, mean)
    top_e = sort(ptb_mean_expr, decreasing=TRUE) %>%
        head(e * length(ptb_mean_expr)) %>%
        names()

    zscore = na.omit(zscores[,idx$id])
    top_z = sort(abs(zscore), decreasing=TRUE) %>%
        head(z * nrow(zscores)) %>%
        names()

    intersect(top_e, top_z)
}

#' Construct data.frame with background gene sets
#'
#' @param expr   List of all input experiments, fields 'records' [list w/ id, etc.]
#'               and 'expr' [genes x arrays]
#' @param zdata  A list with fields 'index' providing experiment info
#'               [data.frame] and 'zscores' [genes x experiments]
#' @return       Character vector of background HGNC symbols per pathway
construct_background = function(expr, zdata) {
    bg_sets = mapply(function(...) exp2background(...) %catch% NULL,
                     idx=expr$records, exp=expr$expr,
                     MoreArgs=list(zscores=zdata$zscores))

    bg_df = stack(bg_sets) %>%
        transmute(id = ind,
                  gene = values,
                  pathway = sub("\\..*$", "", id)) %>%
        group_by(gene, pathway) %>%
        mutate(n=n()) %>%
        ungroup()
}

#' SPEED FET for query set and background (excluding query set)
#'
#' @param cur_id   Experiment ID of form <pathway>.<arrayexpress>.<num>
#' @param bg_sets  Background set data.frame from cosntruct_background()
#' @param n_total  Number of genes measured in total
#' @param o        Overlap to be in bg set
#' @return         Named (pathways) numeric vector of p-values
test_exp = function(cur_id, query_set, bg_sets, n_total, o=0.2) {
    message(cur_id)

    bg_df = bg_sets %>%
        filter(id != cur_id) %>% # exclude only current experiment
#        filter(!grepl(sub("\\.[0-9]+$", "", cur_id), id, fixed=TRUE)) %>% # exclude whole series
        select(pathway, id) %>%
        unique() %>%
        group_by(pathway) %>%
        summarize(n_total=n()) %>%
        right_join(bg_sets, by="pathway")

    sets = bg_df %>%
        mutate(overlap = n/n_total) %>%
        select(pathway, gene, overlap) %>%
        unique() %>%
        filter(overlap >= o) %>%
        select(gene, pathway) %>%
        unstack()

    result = b$lnapply(sets, function(s) {
        vals = c(length(query_set),
                 length(intersect(query_set, s)),
                 n_total,
                 length(s))
        fisher.test(matrix(vals, ncol=2))$p.value
    }) %>% simplify2array()
}

if (is.null(module_name())) {
    EXPR = commandArgs(TRUE)[1] %or% "../../data/expr.RData"
    ZSCORES = commandArgs(TRUE)[2] %or% "../../data/zscores.RData"
    OUTFILE = commandArgs(TRUE)[3] %or% "speed_original.RData"

    # load zscores, model building function, and expression for each experiment
    zdata = io$load(ZSCORES)
    index = zdata$index
    expr = io$load(EXPR)
    stopifnot(colnames(zdata$zscores) == names(expr$expr))

    # get the query sets for each experiment
    query_sets = mapply(fdr_genes$exp2sig, expr=expr$expr, index=expr$records) %>%
        lapply(names)
    query_sets = query_sets[sapply(query_sets, length) != 0]

    # construct a background index
    bg_sets = construct_background(expr, zdata)

    scores = mapply(test_exp, names(query_sets), query_sets,
            MoreArgs=list(bg_sets=bg_sets, n_total=nrow(zdata$zscores))) %>%
        t()
    scores = -log10(scores)

    index = index[match(rownames(scores), index$id),]
    save(scores, index, file=OUTFILE)
}
