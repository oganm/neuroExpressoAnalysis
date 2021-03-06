devtools::load_all()
library(markerGeneProfile)


# white matter grey matter comparison -------------
cortex_white = trabzuniRegionsExp[, c(trabzuniRegionsMeta$brainRegion %in% c('frontal cortex', 'white matter'))]
groups = trabzuniRegionsMeta$brainRegion[trabzuniRegionsMeta$brainRegion %in% c('frontal cortex', 'white matter')]

cortex_white  = data.frame(Gene.Symbol = rownames(cortex_white), cortex_white)

# filter for low expression. this is repeated
# here due to the way initial filtering of trabzuni data is performed
# TrabzuniMedExp is 
cortex_white =
    cortex_white[cortex_white %>% sepExpr %>% {.[[2]]} %>% apply(1,median) %>% {.>TrabzuniMedExp},]

genes = mouseMarkerGenesCombined$Cortex[!grepl('Microglia_',names(neuroExpressoAnalysis::mouseMarkerGenesCombined$Cortex))]

genes = genes[!grepl(pattern = '(?!^Pyramidal$)Pyra',x = names(genes),perl = TRUE)]


genes = genes[(genes %>% sapply(function(x){sum((x %>% mouse2human %$% humanGene) %in% cortex_white$Gene.Symbol)}))>2]


names(genes) = translatePublishable(names(genes))

# 
# fullEstimate(cortex_white,
#              genes=mouseMarkerGenes$Cortex,
#              geneColName="Gene.Symbol",
#              groups=groups,
#              outDir='analysis/04.MarkerGeneProfiles/cortex_white/',
#              seekConsensus=FALSE,
#              groupRotations=TRUE,
#              outlierSampleRemove=FALSE,
#              removeMinority =TRUE,
#              comparisons = 'all',
#              estimateFile = 'analysis/04.MarkerGeneProfiles/cortex_white//estimations')

#genes$`Pyramidal S100a10` = genes$`Pyramidal S100a10`[genes$`Pyramidal S100a10` %in% allowedProbes]

cortex_whiteEstimate = mgpEstimate(cortex_white,
                                   genes= genes,
                                   geneColName="Gene.Symbol",
                                   groups = groups,
                                   outlierSampleRemove= FALSE,
                                   removeMinority=TRUE,
                                   seekConsensus = FALSE
)

cortex_whiteEstimate$estimates = cortex_whiteEstimate$estimates[(cortex_whiteEstimate$rotations %>% sapply(nrow))>1]
cortex_whiteEstimate$groups = cortex_whiteEstimate$groups[(cortex_whiteEstimate$rotations %>% sapply(nrow))>1]
cortex_whiteEstimate$rotations = cortex_whiteEstimate$rotations[(cortex_whiteEstimate$rotations %>% sapply(nrow))>1]

dir.create('analysis/03.MarkerGeneProfiles/estimates',showWarnings = FALSE,recursive = TRUE)
saveRDS(cortex_whiteEstimate,file = 'analysis/03.MarkerGeneProfiles/estimates/cortex_whiteEstimate.rds')

# white matter gray matter plot -------
# as long as outlier samples are not removed all cortex_whiteEstimate$groups will be the same
frame = data.frame(melt(cortex_whiteEstimate$estimates %>% lapply(scale01)), cortex_whiteEstimate$groups[[1]]) 
names(frame) = c('estimation','cellType','brainRegions')
frame$GSM = cortex_whiteEstimate$estimates[[1]] %>% names
frame$cellType  %<>% replaceElement(c('Oligodendrocyte precursors' = 'Olig. precursors' )) %$% newVector

# get gene counts used in the estimation. rotations list hass rotations of the genes in the PCs. Use it to see
# how many genes were used in the estimation
genesUsed = cortex_whiteEstimate$rotations %>% sapply(nrow)
names(genesUsed) %<>% replaceElement(c('Oligodendrocyte precursors' = 'Olig. precursors' )) %$% newVector

numberedNames = paste0(names(genesUsed),'\n(n genes = ', genesUsed, ')')
names(numberedNames) = names(genesUsed)
# ogbox toColor replaces elements of a 
frame$cellType = ogbox::replaceElement(frame$cellType,
                                       numberedNames)$newVector

order = translatePublishable(cellOrder) %>% replaceElement(c('Oligodendrocyte precursors' = 'Olig. precursors' )) %$% newVector

frame %<>% mutate(cellType = cellType %>% 
                      factor(levels =unique(frame$cellType)[unique(frame$cellType) %>% str_extract('^.*?(?=\n)') %>% match(order,.)] %>% trimNAs ))

# estims = read.table('analysis/04.MarkerGeneProfiles/cortex_white/estimations', header=T,sep='\t')
# estims[1:(ncol(estims)-1)] = apply(estims[1:(ncol(estims)-1)],2,scale01)
# 
# list.

#frame =melt(estims)
#names(frame) = c('brainRegions','cellType','estimation')


frame = frame %>% group_by(cellType)
maxY = frame %>% summarise(max(estimation))
wilcoxResults = by(frame, frame$cellType, function(x){
    a1 = x %>% filter(brainRegions == 'frontal cortex') %>% ungroup %>% select(estimation) %>% unlist
    a2 = x %>% filter(brainRegions == 'white matter') %>% ungroup %>%  select(estimation) %>% unlist
    test = wilcox.test(a1,a2)
    
    meanFrontal = mean(a1)
    meanWhite = mean(a2)
    
    sdFrontal = sd(a1)
    sdWhite = sd(a2)
    
    p = test$p.value
    W = unname(test$statistic)
    return(c(p=p,W=W,meanFrontal = meanFrontal,meanWhite = meanWhite, sdFrontal = sdFrontal, sdWhite = sdWhite))
})

ps = wilcoxResults %>% purrr::map_dbl('p')
Ws = wilcoxResults %>% purrr::map_dbl('W')

statTable = data.frame('group' = names(wilcoxResults) %>% str_replace('\n.*',''),
                       'Frontal Cortex Mean' = wilcoxResults %>% purrr::map_dbl('meanFrontal'),
                       'Frontal Cortex SD' = wilcoxResults %>% purrr::map_dbl('sdFrontal'),
                       'White Matter Mean' = wilcoxResults %>% purrr::map_dbl('meanWhite'),
                       'White Matter SD' = wilcoxResults %>% purrr::map_dbl('sdWhite'),
                       'W' =  wilcoxResults %>% purrr::map_dbl('W'),
                       'p value' = wilcoxResults %>% purrr::map_dbl('p'),
                       'adjusted p value'= wilcoxResults %>% purrr::map_dbl('p') %>% p.adjust(method= 'fdr'))

statTable[-1] %<>% round(digits = 3)

dir.create('analysis//03.MarkerGeneProfiles/tables', showWarnings=FALSE)

write.design(statTable,file = 'analysis//03.MarkerGeneProfiles/tables/cortex_WhiteMatterEstimations.tsv')

ps = p.adjust(ps,method='fdr')
markers = ogbox::signifMarker(ps)
signifFrame = data.frame(markers, x= 1.5,y= 1,cellType = names(ps))
# signifFrame %<>% filter(cellType !='PyramidalCorticoThalam')
# frame %<>% 
#     #filter(cellType!='PyramidalCorticoThalam') %>% 
#     ungroup %>% 
#     mutate(cellType = cellType %>% droplevels) %>% group_by(cellType)



p  = frame %>%
    ggplot(aes(x=brainRegions, y = estimation)) + facet_wrap(~cellType,ncol=5) + 
    theme_cowplot(17) + 
    geom_violin( color="#C4C4C4", fill="#C4C4C4") +
    geom_boxplot(width=0.1,fill = 'lightblue') + 
    # geom_point()+
    theme(axis.text.x = element_text(angle=45, hjust = 1),
          strip.text.x = element_text(size = 14)) +
    geom_text(data=signifFrame , aes(x = x, y=y, label = markers),size=10) + 
    coord_cartesian(ylim = c(-0.03, 1.10))  + xlab('') + ylab('MGP estimation')

dir.create('analysis//03.MarkerGeneProfiles/publishPlot', showWarnings=FALSE)

ggsave(filename='analysis//03.MarkerGeneProfiles/publishPlot/cortex_WhiteMatterEstimations.png',p,width=11.31,height=5,units='in')
ggsave(filename='analysis//03.MarkerGeneProfiles/publishPlot/cortex_WhiteMatterEstimations.svg',p,width=11.31,height=5,units='in')



