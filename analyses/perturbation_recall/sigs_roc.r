io = import('io')
st = import('stats')
roc = import('./roc')

zdf = io$load('sigs_zscores.RData') %>%
    roc$scores2df() %>%
    mutate(inferred = sub("\\..*$", "", signature),
           method = "zscore")

gsvadf = io$load('sigs_gsva.RData') %>%
    roc$scores2df() %>%
    mutate(inferred = sub("\\..*$", "", signature),
           method = "gsva")

scoredf = dplyr::bind_rows(zdf, gsvadf)

# per signature, how well do we infer perturbed pathway?
roc = scoredf %>%
    na.omit() %>%
    mutate(matched = perturbed == inferred) %>%
    group_by(method, inferred, signature) %>%
    do(st$roc(., "score", "matched")) %>%
    ungroup()

width=1
random_line = data.frame(x=c(0,1), y=c(0,1), method=roc$signature[1])
ggplot(roc, aes(x=FPR, y=TPR, color=method)) +
    geom_line(aes(x=x, y=y), data=random_line, color="grey", linetype="dashed", size=width) +
    stat_summary(aes(fill=method), geom="ribbon", alpha=0.2,
                 fun.ymin = min,
                 fun.ymax = max) +
#    geom_step(size=width, stat="summary", fun.y=median) +
    coord_fixed() +
    facet_wrap(~inferred) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
