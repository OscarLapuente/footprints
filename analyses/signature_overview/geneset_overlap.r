library(dplyr)
library(magrittr)
plt = import('plot')
get_genesets = import('../../util/genesets')$get

set2overlap = function(sets, fun=function(x,y) nrow(dplyr::intersect(x,y))) {
    uniquify_colnames = function(df) {
        colnames(df) = make.names(colnames(df), unique=TRUE)
        df
    }

    sets %>%
        group_by(method) %>%
        tidyr::nest() %>%
        merge(., ., by=NULL) %>% # tidyr::crossing() produces error
        transmute(method1 = method.x,
                  method2 = method.y,
                  overlap = purrr::map2_int(data.x, data.y, fun))
}

geneset_overlap_matrix = function(sets) {
    sorted = unique(sets$method)

    overlaps = sets %>%
        group_by(pathway) %>%
        tidyr::nest() %>%
        mutate(data = purrr::map(data, ~ set2overlap(.))) %>%
        tidyr::unnest() %>%
        mutate(method1 = factor(method1, levels=rev(sorted)),
               method2 = factor(method2, levels=sorted)) %>%
        filter(as.integer(method1) > length(sorted)-as.integer(method2))

    plt$matrix(overlaps, overlap ~ method1 + method2, palette="Blues") +
        geom_text(aes(label=overlap), size=3) +
        coord_fixed() +
        theme(legend.position = "none",
              text = element_text(size=10),
              axis.text.x = element_text(size=8),
              axis.text.y = element_text(size=8)) +
        facet_wrap(~pathway) + 
        xlab("") +
        ylab("")
}

if (is.null(module_name())) {
    OUTFILE = commandArgs(TRUE)[1]

    pdf(OUTFILE)
    on.exit(dev.off)

    sets = get_genesets()
    geneset_overlap_matrix(sets)
}
