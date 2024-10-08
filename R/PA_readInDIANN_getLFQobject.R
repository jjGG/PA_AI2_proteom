#!/usr/local/bin/Rscript
#
# Jonas Grossmann <jg@fgcz.ethz.ch>
# 2024
#
#

# set working directory to source file location
# setwd("~/GitHub/PA_AI2_proteom/R")

# here we develop an Rscript to analyze LFQ-DIA data analyzed w/ DIANN and using
# prolfqua and proflquapp

# here path to install packages



library(prolfqua)
library(prolfquapp)
library(stringr)

# globals
fgczproject <- "o35868"
approach <- "PA_AI2"

# go old-school without prolfquapp reporting but w/ two factors for the modelling!

# prolfquapp function to get directly fasta and proper DIANN-output into x object
x <- get_DIANN_files(path = "../data/")

# parse and QC-check dataset
# here we may add later more factors parsed from Grouping.Var or do it directly on the lfqobject$data
myannotation <- file.path("../data/dataset.csv") |>
  readr::read_csv() |> prolfquapp::read_annotation(QC = TRUE)
myannotation

# in this step we filter for DIANN qvalue 0.01 and also directly label decyos and contaminants!
# read in minimal yaml tot find path
#yml <- yaml::read_yaml("../data/minimal.yaml")
#dir.create(yml$path) # necessairy as expected by proflquapp

xd <- preprocess_DIANN(quant_data = x$data, fasta_file = x$fasta, annotation = myannotation)
str(xd$protein_annotation)


# roll up to proteins -> T3PQ
myMethod <- "topN" # by default topN is 3
logger::log_info("AGGREGATING PEPTIDE DATA: {myMethod}")
lfqdata <- prolfquapp::aggregate_data(xd$lfqdata, agg_method = myMethod)
logger::log_info("END OF PROTEIN AGGREGATION")

lfqdata$data
# maybe here join  in w/ xd$protein_annotation


# transform and normalize (log2nrobscale)
# method = c("robscale", "vsn", "none", "log2")


lt <- lfqdata$get_Transformer()
logger::log_info("Transforming using robscale.")
transformed <- lt$log2()$robscale()$lfq
transformed$data

# maybe show effect of normalization?
# before normalization
lfqplotter <- lfqdata$get_Plotter()
density_nn <- lfqplotter$intensity_distribution_density()

# Transformation & Normalization
pl <- transformed$get_Plotter()
density_norm <- pl$intensity_distribution_density()


(fN <- paste(fgczproject, "_", approach, "_EffectOfNormalization", ".pdf",sep = ""))
pdf(fN, 15,15)
# before n after trafo n normalization
gridExtra::grid.arrange(density_nn, density_norm)
dev.off()



# add info on protein level about genotype and growingCondition

unique(transformed$data$Name)
transformed$data$Name <- gsub(x = transformed$data$Name, pattern = "AI2_10", replacement = "AI2ten")
transformed$data$Name <- gsub(x = transformed$data$Name, pattern = "AI2_1", replacement = "AI2one")
table(unlist(lapply(str_split(string = unique(transformed$data$Name), pattern = "_"),FUN = "[",1)))
transformed$data$Condition <- unlist(lapply(str_split(string = transformed$data$Name, pattern = "_"),FUN = "[",1))


# get factors and response correct -> better start from scratch again! completely!
#transformed$config$table$factor_keys_depth()
#transformed$config$table$factor_keys()


# join data and annotations
mydata <- transformed$data
colnames(mydata)
length(unique(mydata$protein_Id))

# inner working of prolfqua
# define analysis table (what to take along)
table <- prolfqua::AnalysisTableAnnotation$new()
table$set_response("transformedIntensity")
table$hierarchy[["Protein_ID"]] = c("protein_Id")

# define factors that are important
table$fileName = "Name"
table$factors[["Condition"]] <- "Condition"
table$factorDepth <- 1 # nur 2 faktoren und nicht run_id !

# create configuration prolfqua - v1.5.5 necessairy
config <- prolfqua::AnalysisConfiguration$new(table)

# setup analysis with config and data
data2 <- setup_analysis(mydata , config)

# go for lfq quant data with configuration
lfqdata <- LFQData$new(data2, config)
lfqdata$to_wide()
lfqdata$factors()
lfqdata$config$table$id_required()

# get transformer PlotterAndSummariser Objects
pl <- lfqdata$get_Plotter()
lfqSum <- lfqdata$get_Summariser()
stats <- lfqdata$get_Stats()

# maybe all plotting devices have to first be completely closed
# use maybe multiple times!
# dev.off()
dev.off()
(fN <- paste(fgczproject, "_", approach, "_VisualizeInput", ".pdf",sep = ""))
pdf(fN, 15,15)
# before n after trafo n normalization
gridExtra::grid.arrange(density_nn, density_norm)

#summary
lfqSum$plot_missingness_per_group()
lfqSum$plot_hierarchy_counts_sample()
lfqSum$plot_missingness_per_group_cumsum()
pl$missigness_histogram()
plot.new()
pl$NA_heatmap()

# stats
stats$violin()
stats$density_median()

# QC plots
#pl$pairs_smooth()
p <- pl$heatmap_cor()
plot.new()
p
plot.new()
pl$heatmap()
plot.new()
pl$pca()
dev.off()

(fN <- paste(fgczproject, "_", approach, "_lfqDataObject", ".RData", sep = ""))
save(lfqdata, file = fN)
