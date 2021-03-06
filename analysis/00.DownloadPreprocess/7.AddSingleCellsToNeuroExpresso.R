library(ogbox)
devtools::load_all()

singleCells = ogbox::read.design('data-raw/Mouse_Cell_Type_Data/singleCellMatchings.tsv')

# get means for primary cell types
TasicPrimaryMean = TasicMouseMeta$primary_type %>% unique %>% lapply(function(x){
    TasicMouseExp[,TasicMouseMeta$sample_title[TasicMouseMeta$primary_type %in% x]] %>% apply(1,mean)
}) %>% as.data.frame
names(TasicPrimaryMean)  =  TasicMouseMeta$primary_type %>% unique


# dealing with duplicates ----------------
mouse_genes = read.design('data-raw/GemmaAnnots/Generic_mouse')
GPL1261 = read.design('data-raw/GemmaAnnots/GPL1261')

tasic_synonyms = rownames(TasicPrimaryMean)[!rownames(TasicPrimaryMean) %in% mouse_genes$GeneSymbols] %>% mouseSyno()

missing_in_tasic = GPL1261$GeneSymbols[!GPL1261$GeneSymbols %in%  rownames(TasicPrimaryMean)]

missing_in_tasic = GPL1261 %>% filter(GeneSymbols != '' & !GeneSymbols %in% rownames(TasicPrimaryMean) & !grepl('\\|',GeneSymbols)) %$% GeneSymbols %>% unique


replaceGenes = seq_along(tasic_synonyms) %>% lapply(function(i){
    # check if any of them are first names
    firstName = sapply(tasic_synonyms[[i]],function(x){
        
        x[1] == names(tasic_synonyms[i])
    })
    if((tasic_synonyms[[i]] %>% purrr::map_chr(1) %in% mouse_genes$GeneSymbols %>% sum %>% {.==1}) &&
       !tasic_synonyms[[i]] %>% purrr::map_chr(1) %in% rownames(TasicPrimaryMean)){
        # if a first name matches anything in gemma, pick that. the other synonyms are probably not right
        return(tasic_synonyms[[i]] %>% purrr::map_chr(1) %>% {.[. %in% mouse_genes$GeneSymbols]} %>% unname)
    } else if (any(unlist(tasic_synonyms[[i]]) %in% mouse_genes$GeneSymbols)){
        # if a first name doesn't match anything in gemma try to pick a unique secondary name
        out = mouse_genes$GeneSymbols[mouse_genes$GeneSymbols %in% unlist(tasic_synonyms[[i]])]
        # remove the gene if it appears multiple times and if a gene with the same is already there
        if(length(out) > 1 || (length(out) == 1 && out %in% rownames(TasicPrimaryMean))){
            out = character(0)
        }
        return(unname(out))
    } else if(sum(firstName)==1){
        # if there is a single new first name take that name. it's probably the
        # right and Gemma gene is probably outdates. this doesn't seem to contradict gemma 
        # at all. note that there seems to be a few cases of repeating first names but those seem to be all 
        # reciprocal translocations
        return(unname(tasic_synonyms[[i]][firstName][[1]][[1]]))
    } 
}) 

names(replaceGenes) = names(tasic_synonyms) 
replaceGenes %<>% unlist

replaceGenes = replaceGenes[!replaceGenes %in% replaceGenes[replaceGenes %>% duplicated]]

newRownames = rownames(TasicPrimaryMean) %>% ogbox::replaceElement(replaceGenes) %$% newVector

stillMissingInTasic = GPL1261 %>% filter(GeneSymbols != '' & !GeneSymbols %in% newRownames & !grepl('\\|',GeneSymbols)) %$% GeneSymbols %>% unique

# stillMissingInTasic %>% mouseSyno() %>% purrr::map(unlist) %>% purrr::map_lgl(function(x){
#     any(x %in% unlist(tasic_synonyms))
# }) %>% which

rownames(TasicPrimaryMean) = newRownames

tasicGeneIds = vector(mode='character',length = nrow(TasicPrimaryMean))
tasicGeneIds[newRownames %in% GPL1261$GeneSymbols] = GPL1261$NCBIids[match(newRownames,GPL1261$GeneSymbols) %>% na.omit()]
tasicGeneIds[tasicGeneIds==''] = newRownames[tasicGeneIds=='']  %>% mouseSyno() %>%  sapply(function(x){
    if(length(x)==1 && !is.null(names(x))){
        return(names(x))
    } else{
        return('')
    }
})
# fiddling with expresssion data ---------------

rnaSeqMed = TasicPrimaryMean %>% {.+1} %>%log(base=2) %>% unlist %>% median

# filter expression values (low level filter)
keep = (TasicPrimaryMean %>% apply(1,max))>(TasicPrimaryMean %>% unlist %>% median)
tasicGeneIds = tasicGeneIds[keep]
TasicPrimaryMean = TasicPrimaryMean[keep,]

TasicPrimaryMeanLog = TasicPrimaryMean %>% {.+1} %>%log(base=2)


TasicPrimaryMeanComparable = TasicPrimaryMean %>% 
    apply(2,qNormToValues,values =  n_expressoExpr %>%
              sepExpr %>% {.[[2]]} %>% unlist) %>%
    as.df
rownames(TasicPrimaryMeanComparable) = rn(TasicPrimaryMean)



TasicPrimaryMeanSubset =  TasicPrimaryMean %>% {.[rn(.) %in% n_expressoExpr$Gene.Symbol,]}
n_ExpressoSubset = n_expressoExpr[match(rn(TasicPrimaryMeanSubset), n_expressoExpr$Gene.Symbol),]

TasicPrimaryMeanComparableRows = mapply(function(tasic,neuro){
    qNormToValues(tasic,neuro)
},
t(TasicPrimaryMeanSubset) %>% as.df ,n_ExpressoSubset %>% sepExpr %>% {.[[2]]} %>% t %>% as.df) %>% t %>% as.df

names(TasicPrimaryMeanComparableRows) = names(TasicPrimaryMean)



sampleLines = singleCells$Tasic %>% str_split(', ')

samples = unlist(sampleLines)


meltedSingleCells = samples %>% sapply(function(x){
    if(!x==''){
        findInList(x , sampleLines)
    } else{
        NULL
    }
}) %>% unlist %>% {
    out = singleCells[.,]
    out$sample = names(.)
    return(out)
}


set.seed(1)
meltedSingleCells %<>%
{data.frame(sampleName =.$sample,
            originalIndex = stri_rand_strings(nrow(.),6),
            GSE =  'GSE71585',
            samples = .$Tasic,
            MajorType = .$MajorType,
            Neurotransmitter = .$Neurotransmitter,
            ShinyNames = .$ShinyNames  %>% replaceElement(NA,'') %$%newVector,
            CellTypes =  .$CellTypes %>% replaceElement(NA,'') %$%newVector,
            PyramidalDeep = .$PyramidalDeep %>% replaceElement(NA,'') %$%newVector,
            BroadTypes = NA,
            Description = NA,
            Age = NA,
            Region = .$Region,
            Method = 'RNAseq',
            Platform = 'RNAseq',
            Reference = 'Tasic et al.',
            PMID = 26727548,
            RegionToChildren = TRUE,
            RegionToParent = TRUE,
            Normalize = TRUE,
            Normalize2= TRUE,
            Notes = '',
            stringsAsFactors = FALSE)}

TasicPrimaryMean = TasicPrimaryMean[meltedSingleCells$sampleName]
# used in neuroexpresso.org
TasicPrimaryMeanComparable = TasicPrimaryMeanComparable[meltedSingleCells$sampleName]
TasicPrimaryMeanLog = TasicPrimaryMeanLog[meltedSingleCells$sampleName]
use_data(meltedSingleCells, overwrite = TRUE)

TasicPrimaryMean %<>% tibble::add_column(Gene.Symbol = rn(TasicPrimaryMean), NCBIids = tasicGeneIds,.before = 1)
use_data(TasicPrimaryMean, overwrite = TRUE)

TasicPrimaryMeanLog %<>% tibble::add_column(Gene.Symbol = rn(TasicPrimaryMeanLog), NCBIids = tasicGeneIds,.before = 1)
use_data(TasicPrimaryMeanLog, overwrite = TRUE)

TasicPrimaryMeanComparable %<>% tibble::add_column(Gene.Symbol = rn(TasicPrimaryMeanLog), NCBIids = tasicGeneIds,.before = 1)
use_data(TasicPrimaryMeanComparable, overwrite = TRUE)

write.design(meltedSingleCells,file = 'data-raw/Mouse_Cell_Type_Data/meltedSingleCells.tsv')
write.csv(TasicPrimaryMeanComparable,file = 'data-raw/Mouse_Cell_Type_Data/TasicPrimaryMeanComparable.csv',row.names=FALSE )
write.csv(TasicPrimaryMean,file = 'data-raw/Mouse_Cell_Type_Data/TasicPrimaryMean.csv',row.names=FALSE )


# used in neuroexpresso.org
n_expressoSamplesWithRNAseq = rbind(n_expressoSamples, meltedSingleCells)

# n_expressoExprWithRNAseq = cbind(n_expressoExpr[n_expressoExpr$Gene.Symbol %in% rn(TasicPrimaryMeanComparable),],
#                                  TasicPrimaryMeanComparable[match(n_expressoExpr$Gene.Symbol[n_expressoExpr$Gene.Symbol %in% rn(TasicPrimaryMeanComparable)],
#                                                                   rn(TasicPrimaryMeanComparable)),])

n_expressoExprWithRNAseq = cbind(n_expressoExpr, TasicPrimaryMeanComparable[match(n_expressoExpr$Gene.Symbol,
                                                                                  rn(TasicPrimaryMeanComparable)),-c(1,2)])
# n_expressoExprWithRNAseq[n_expressoExprWithRNAseq$Gene.Symbol %in% 'Nrk',]
write.design(n_expressoSamplesWithRNAseq,'data-raw/Mouse_Cell_Type_Data/n_expressoSamplesWithRNAseq.tsv')
use_data(n_expressoSamplesWithRNAseq,overwrite = TRUE)
use_data(n_expressoExprWithRNAseq,overwrite = TRUE)
write.csv(n_expressoExprWithRNAseq,file = 'data-raw/Mouse_Cell_Type_Data/n_expressoExprWithRNAseq.csv',row.names=FALSE )


# n_expressoExprWithRNAseqRowNorm = cbind(n_expressoExpr[n_expressoExpr$Gene.Symbol %in% rn(TasicPrimaryMeanComparableRows),],
#                                         TasicPrimaryMeanComparableRows[match(n_expressoExpr$Gene.Symbol[n_expressoExpr$Gene.Symbol %in% rn(TasicPrimaryMeanComparableRows)],
#                                                                              rn(TasicPrimaryMeanComparableRows)),])
#write.csv(n_expressoExprWithRNAseqRowNorm,file = 'data-raw/Mouse_Cell_Type_Data/n_expressoExprWithRNAseqRowNorm.csv',row.names=FALSE )
#use_data(n_expressoExprWithRNAseqRowNorm,overwrite = TRUE)


n_expressoSamples2 = read.design('data-raw/Mouse_Cell_Type_Data/n_expressoSamples2.tsv')
n_expressoExpr2 = read.exp("data-raw/Mouse_Cell_Type_Data/n_expressoExpr2.csv")
n_expressoSamplesWithRNAseq2 = rbind(n_expressoSamples2, meltedSingleCells)
write.design(n_expressoSamplesWithRNAseq2,'data-raw/Mouse_Cell_Type_Data/n_expressoSamplesWithRNAseq2.tsv')


# n_expressoExprWithRNAseq2 = cbind(n_expressoExpr2[n_expressoExpr2$Gene.Symbol %in% rn(TasicPrimaryMeanComparable),],
#                                  TasicPrimaryMeanComparable[match(n_expressoExpr2$Gene.Symbol[n_expressoExpr2$Gene.Symbol %in% rn(TasicPrimaryMeanComparable)],
#                                                                   rn(TasicPrimaryMeanComparable)),])
n_expressoExprWithRNAseq2 = cbind(n_expressoExpr2, TasicPrimaryMeanComparable[match(n_expressoExpr2$Gene.Symbol,
                                                                                    rn(TasicPrimaryMeanComparable)),-c(1,2)])
write.csv(n_expressoExprWithRNAseq2,file = 'data-raw/Mouse_Cell_Type_Data/n_expressoExprWithRNAseq2.csv',row.names=FALSE )


#n_expressoExprWithRNAseq2RowNorm = cbind(n_expressoExpr2[n_expressoExpr2$Gene.Symbol %in% rn(TasicPrimaryMeanComparableRows),],
#                                         TasicPrimaryMeanComparableRows[match(n_expressoExpr2$Gene.Symbol[n_expressoExpr2$Gene.Symbol %in% rn(TasicPrimaryMeanComparableRows)],
#                                                                   rn(TasicPrimaryMeanComparableRows)),])

#write.csv(n_expressoExprWithRNAseq2RowNorm,file = 'data-raw/Mouse_Cell_Type_Data/n_expressoExprWithRNAseq2RowNorm.csv',row.names=FALSE )



