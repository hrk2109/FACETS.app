#!/opt/common/CentOS_6-dev/R/R-3.1.3/bin/Rscript

### modified version of doFacets.R
###
### runs FACETS twice with two sets of input parameters
### dipLogR from the first iteration is used for the second
### output files for both iterations are retained

library(facets)
library(Cairo)

getSDIR <- function(){
    args=commandArgs(trailing=F)
    TAG="--file="
    path_idx=grep(TAG,args)
    SDIR=dirname(substr(args[path_idx],nchar(TAG)+1,nchar(args[path_idx])))
    if(length(SDIR)==0) {
        return(getwd())
    } else {
        return(SDIR)
    }
}

source(file.path(getSDIR(),"funcs.R"))
source(file.path(getSDIR(),"fPlots.R"))
source(file.path(getSDIR(),"nds.R"))

buildData=installed.packages()["facets",]
cat("#Module Info\n")
for(fi in c("Package","LibPath","Version","Built")){
    cat("#",paste(fi,":",sep=""),buildData[fi],"\n")
}
version=buildData["Version"]
cat("\n")

library(argparse)
parser=ArgumentParser()

parser$add_argument("-c","--cval",type="integer",default=50,help="critical value for segmentation")
parser$add_argument("-s","--snp_nbhd",type="integer",default=250,help="window size")
parser$add_argument("-n","--ndepth",type="integer",default=35,help="threshold for depth in the normal sample")
parser$add_argument("-m","--min_nhet",type="integer",default=25,
    help="minimum number of heterozygote snps in a segment used for bivariate t-statistic during clustering of segments")

parser$add_argument("-pc","--purity_cval",type="integer",default=50,help="critical value for segmentation")
parser$add_argument("-ps","--purity_snp_nbhd",type="integer",default=250,help="window size")
parser$add_argument("-pn","--purity_ndepth",type="integer",default=35,help="threshold for depth in the normal sample")
parser$add_argument("-pm","--purity_min_nhet",type="integer",default=25,
    help="minimum number of heterozygote snps in a segment used for bivariate t-statistic during clustering of segments")

parser$add_argument("-d","--dipLogR",type="double",default=-99,help="diploid log ratio")
parser$add_argument("--genome",type="character",default="hg19",help="Genome of counts file")
parser$add_argument("file",nargs=1,help="Paired Counts File")
args=parser$parse_args()

NDEPTH=args$ndepth
SNP_NBHD=args$snp_nbhd
CVAL=args$cval
MIN_NHET=args$min_nhet

PURITY_NDEPTH=args$purity_ndepth
PURITY_SNP_NBHD=args$purity_snp_nbhd
PURITY_CVAL=args$purity_cval
PURITY_MIN_NHET=args$purity_min_nhet

FILE=args$file
DIPLOGR=args$dipLogR
if(DIPLOGR==-99){
    DIPLOGR=NULL
}
BASE=basename(FILE)
BASE=gsub("countsMerged____","",gsub(".dat.*","",BASE))

sampleNames=gsub(".*recal_","",strsplit(BASE,"____")[[1]])
tumorName=sampleNames[1]
normalName=sampleNames[2]
projectName=gsub("_indel.*","",strsplit(BASE,"____")[[1]])[1]

switch(args$genome,
    hg19={
        data(hg19gcpct)
        chromLevels=c(1:22, "X")
    },
    mm9={
        data(mm9gcpct)
        chromLevels=c(1:19)
    },
    {
        stop(paste("Invalid Genome",args$genome))
    }
)

facets_iteration <- function(CVAL = CVAL,
                             DIPLOGR = DIPLOGR,
                             NDEPTH = NDEPTH,
                             SNP_NBHD = SNP_NBHD,
                             MIN_NHET = MIN_NHET){

    TAG=paste("facets",projectName,tumorName,normalName,"cval",CVAL,sep="__")
    TAG1=cc(projectName,tumorName,normalName)
    
    
    pre.CVAL=50
    dat=preProcSample(FILE,snp.nbhd=SNP_NBHD,cval=pre.CVAL,chromlevels=chromLevels,ndepth=NDEPTH)
    
    out=procSample(dat,cval=CVAL,min.nhet=MIN_NHET,dipLogR=DIPLOGR)
    
    CairoPNG(file=cc(TAG,"BiSeg.png"),height=1000,width=800)
    plotSample(out,chromlevels=chromLevels)
    text(-.08,-.08,paste(projectName,"[",tumorName,normalName,"]","cval =",CVAL),xpd=T,pos=4)
    dev.off()
    
                                        #fit=emcncf(out$jointseg,out$out,dipLogR=out$dipLogR) OLD
    fit=emcncf(out) # NEW
    out$IGV=formatSegmentOutput(out,TAG1)
    save(out,fit,file=cc(TAG,".Rdata"),compress=T)
    write.table(out$IGV,file=cc(TAG,'.seg'),row.names=F,quote=F,sep="\t") #NEW
    
    ff=cc(TAG,".out")
    cat("# TAG =",TAG1,"\n",file=ff)
    cat("# Version =",version,"\n",file=ff,append=T)
    cat("# Input =",basename(FILE),"\n",file=ff,append=T)
    cat("# snp.nbhd =",SNP_NBHD,"\n",file=ff,append=T)
    cat("# cval =",CVAL,"\n",file=ff,append=T)
    cat("# min.nhet =",MIN_NHET,"\n",file=ff,append=T)
    cat("# genome =",args$genome,"\n",file=ff,append=T)
    cat("# Project =",projectName,"\n",file=ff,append=T)
    cat("# Tumor =",tumorName,"\n",file=ff,append=T)
    cat("# Normal =",normalName,"\n",file=ff,append=T)
    cat("# Purity =",fit$purity,"\n",file=ff,append=T)
    cat("# Ploidy =",fit$ploidy,"\n",file=ff,append=T)
    cat("# dipLogR =",fit$dipLogR,"\n",file=ff,append=T)
    cat("# dipt =",fit$dipt,"\n",file=ff,append=T)
    cat("# loglik =",fit$loglik,"\n",file=ff,append=T)
    
    write.xls(cbind(out$IGV[,1:4],fit$cncf[,2:ncol(fit$cncf)]),
              cc(TAG,"cncf.txt"),row.names=F)
    
    CairoPNG(file=cc(TAG,"CNCF.png"),height=1100,width=850)
                                        #plotSampleCNCF(out$jointseg,out$out,fit)
    plotSampleCNCF.custom(out$jointseg,out$out,fit,
                          main=paste(projectName,"[",tumorName,normalName,"]","cval =",CVAL))
    
    dev.off()

    return(fit$dipLogR)
}

estimated_dipLogR <- facets_iteration(PURITY_CVAL,           DIPLOGR, PURITY_NDEPTH, PURITY_SNP_NBHD, PURITY_MIN_NHET)
                     facets_iteration(       CVAL, estimated_dipLogR,        NDEPTH,        SNP_NBHD,        MIN_NHET)
