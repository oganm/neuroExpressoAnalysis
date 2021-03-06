# download the cel files for mouse cell type data
# design file was generated in house
# this assumes your working directory is the root of the repository
library(ogbox)
library(dplyr)
library(magrittr)
library(praise)
library(devtools)
devtools::load_all()
# skip norm is for when cellTypeStudies.tsv is modified without addition or removal of any new 
# samples
skipNorm=F
download = F

# library(cellTypeManuscript)

design = ogbox::read.design('data-raw/Mouse_Cell_Type_Data/n_expressoStudies.tsv')

# this design file is available in the package as cellTypeStudies
n_expressoStudies = design
usethis::use_data(n_expressoStudies, overwrite=TRUE)

# download the cell type data for the study -----------------------------------------
# design$sampleName includes all sample names included in neuroexpresso database. 
# non-GEO samples should be acquired through personal communication.
# to download samples from GEO we need to extract their GSM identifiers.
# for ease of organization we place the samples from different platforms to their own folders
# here there is some code for me to generate the files acquired through personal
# communication. If asked, I can share this file.
personalCommunicationSamples = 
    design %>% apply(1,function(x){
        samples = stringr::str_split(x['samples'],',')[[1]]
        samples = samples[!grepl('GSM[0-9]*',samples)]
        file.path(x['Platform'],glue::glue('{samples}.CEL'))
    }) %>% unlist

tar('data-raw/personalCommunicationSamples.tar.gz',
    files = file.path('data-raw/cel',personalCommunicationSamples)
    ,compression = 'gzip',
    tar = 'tar -h')

if (download){
    GPL339 = design %>% filter(Platform == 'GPL339')
    GPL1261 = design %>% filter(Platform == 'GPL1261')
    
    dir.create('data-raw/cel/GPL339/', showWarnings = FALSE)
    GSM339 = stringr::str_extract_all(GPL339$samples,pattern='GSM[0-9]*') %>% unlist
    # download all GSMs
    GSM339 %>% sapply(function(x){
        ogbox::gsmDown(gsm=x,
                       outfile=paste0('data-raw/cel/GPL339/',x,'.CEL'))
    })
    
    dir.create('data-raw/cel/GPL1261/', showWarnings = FALSE)
    GPL1261 =  stringr::str_extract_all(GPL1261$samples,pattern='GSM[0-9]*') %>% unlist
    # download all GSMs
    GPL1261 %>% sapply(function(x){
        ogbox::gsmDown(gsm=x,
                       outfile=paste0('data-raw/cel/GPL1261/',x,'.cel'))
    })
    
    # before normalization, download probe to gene annotations from gemma
    dir.create('data-raw/GemmaAnnots', showWarnings=FALSE)
    gemmaAPI::getAnnotation('GPL339',annotType = 'noParents',file = 'data-raw/GemmaAnnots/GPL339',overwrite = TRUE)
    gemmaAPI::getAnnotation('GPL1261',annotType = 'noParents',file = 'data-raw/GemmaAnnots/GPL1261',overwrite = TRUE)
    gemmaAPI::getAnnotation('GPL1261',annotType = 'noParents',file = 'data-raw/GemmaAnnots/GPL1261',overwrite = TRUE)
    
    ogbox::getGemmaAnnot('GPL339','data-raw/GemmaAnnots/GPL339',annotType='noParents',overwrite = TRUE)
    ogbox::getGemmaAnnot('GPL1261','data-raw/GemmaAnnots/GPL1261',annotType='noParents',overwrite = TRUE)
    # also get the all mouse annotations. we will use this later to with RNA-seq data. It is important
    # that these files are acquired at the same time
    ogbox::getGemmaAnnot('Generic_mouse','data-raw/GemmaAnnots/Generic_mouse',annotType='noParents',overwrite = TRUE)
    ogbox::getGemmaAnnot('Generic_mouse_ensemblIds','data-raw/GemmaAnnots/Generic_mouse_ensembl',annotType='noParents',overwrite = TRUE)
    
    
}

# normalization of the data ----------------
# here we create a file that includes all data by merging data from GPL339 and GPL1261 and one
# that only has samples from GPL1261. While we select marker genes for this file as well, 
# the data and the markers are not included in the project repository


if (skipNorm==F){
    readDesignMergeCel(desFile='data-raw/Mouse_Cell_Type_Data/n_expressoStudies.tsv',
                       gsm = 'samples',
                       normalize = 'Normalize',
                       celRegex = "(GSM.*?(?=,|$))|(PC\\d....)|(Y[+].*?((?=(,))|\\d+))|((?<=[,])|(^))A((9)|(10))_[0-9]{1,}_Chee_S1_M430A|(v2_(?![G,H,r]).*?((?=(,))|($)))|(SSC.*?((?=(,))|($)))|(MCx.*?((?=(,))|($)))|(Cbx.*?((?=(,))|($)))",
                       celDir = 'data-raw/cel', 
                       expFile = 'data-raw/Mouse_Cell_Type_Data/rmaExp.csv',
                       desOut = 'data-raw/Mouse_Cell_Type_Data/n_expressoSamples.tsv',
                       gemmaDir = "data-raw/GemmaAnnots")
    
    readDesignMergeCel(desFile='data-raw/Mouse_Cell_Type_Data/n_expressoStudies.tsv',
                       gsm = 'samples',
                       normalize = 'Normalize2',
                       celRegex = "(GSM.*?(?=,|$))|(PC\\d....)|(Y[+].*?((?=(,))|\\d+))|((?<=[,])|(^))A((9)|(10))_[0-9]{1,}_Chee_S1_M430A|(v2_(?![G,H,r]).*?((?=(,))|($)))|(SSC.*?((?=(,))|($)))|(MCx.*?((?=(,))|($)))|(Cbx.*?((?=(,))|($)))",
                       celDir = 'data-raw/cel', 
                       expFile = 'data-raw/Mouse_Cell_Type_Data/rmaExp2.csv',
                       desOut = 'data-raw/Mouse_Cell_Type_Data/n_expressoSamples2.tsv',
                       gemmaDir = "data-raw/GemmaAnnots")
    
    quantileNorm('data-raw/Mouse_Cell_Type_Data/rmaExp.csv',
                 'data-raw/Mouse_Cell_Type_Data/qnormExp.csv')
    
    quantileNorm('data-raw/Mouse_Cell_Type_Data/rmaExp2.csv',
                 'data-raw/Mouse_Cell_Type_Data/qnormExp2.csv')
        
    mostVariableCT(whichFile = 'data-raw/Mouse_Cell_Type_Data/qnormExp.csv',
                   outFile = 'data-raw/Mouse_Cell_Type_Data/n_expressoExpr.csv',
                   cellTypeColumn = 'PyramidalDeep',
                   design = 'data-raw/Mouse_Cell_Type_Data/n_expressoSamples.tsv')
    
    mostVariableCT(whichFile = 'data-raw/Mouse_Cell_Type_Data/qnormExp2.csv',
                   outFile = 'data-raw/Mouse_Cell_Type_Data/n_expressoExpr2.csv',
                   cellTypeColumn = 'PyramidalDeep',
                   design = 'data-raw/Mouse_Cell_Type_Data/n_expressoSamples2.tsv')
    
} else if (skipNorm == T){
    meltDesign(desFile='data-raw/Mouse_Cell_Type_Data/n_expressoStudies.tsv',
               gsm = 'samples',
               normalize = 'Normalize',
               celRegex = "(GSM.*?(?=,|$))|(PC\\d....)|(Y[+].*?((?=(,))|\\d+))|((?<=[,])|(^))A((9)|(10))_[0-9]{1,}_Chee_S1_M430A|(v2_(?![G,H,r]).*?((?=(,))|($)))|(SSC.*?((?=(,))|($)))|(MCx.*?((?=(,))|($)))|(Cbx.*?((?=(,))|($)))",
               exprFile = 'data-raw/Mouse_Cell_Type_Data/n_expressoExpr.csv',
               outFile = 'data-raw/Mouse_Cell_Type_Data/n_expressoSamples.tsv')
    
    meltDesign(desFile='data-raw/Mouse_Cell_Type_Data/n_expressoStudies.tsv',
               gsm = 'samples',
               normalize = 'Normalize2',
               celRegex = "(GSM.*?(?=,|$))|(PC\\d....)|(Y[+].*?((?=(,))|\\d+))|((?<=[,])|(^))A((9)|(10))_[0-9]{1,}_Chee_S1_M430A|(v2_(?![G,H,r]).*?((?=(,))|($)))|(SSC.*?((?=(,))|($)))|(MCx.*?((?=(,))|($)))|(Cbx.*?((?=(,))|($)))",
               exprFile = 'data-raw/Mouse_Cell_Type_Data/n_expressoExpr2.csv',
               outFile = 'data-raw/Mouse_Cell_Type_Data/n_expressoSamples2.tsv')
    
    praise("${EXCLAMATION}! ${Adverb} ${created}")
    
    #system('gzip -f data-raw/Mouse_Cell_Type_Data/rmaExp.csv')
    #system('gzip -f data-raw/Mouse_Cell_Type_Data/qnormExp.csv')
    #system('gzip -f data-raw/Mouse_Cell_Type_Data/rmaExp2.csv')
    #system('gzip -f data-raw/Mouse_Cell_Type_Data/qnormExp2.csv')
}

# now load the data and place it in the package
n_expressoExpr = ogbox::read.exp('data-raw//Mouse_Cell_Type_Data//n_expressoExpr.csv')
n_expressoSamples =  ogbox::read.design('data-raw/Mouse_Cell_Type_Data/n_expressoSamples.tsv')


usethis::use_data(n_expressoExpr,overwrite=TRUE)
usethis::use_data(n_expressoSamples,overwrite=TRUE)

regionHierarchy = list(All = list(Cerebrum = 
                                      list(Cortex = '',
                                           BasalForebrain ='',
                                           Striatum = '',
                                           Amygdala ='',
                                           Hippocampus = ''),
                                  Subependymal = '',
                                  Thalamus = '',
                                  Brainstem = 
                                      list(Midbrain = list(SubstantiaNigra = ''),
                                           LocusCoeruleus=''),
                                  Cerebellum = '',
                                  SpinalCord ='')
)
usethis::use_data(regionHierarchy,overwrite = TRUE)

