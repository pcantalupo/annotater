#!/usr/bin/env Rscript

# This script detects if the second argument ('acc') is a file or a single accession number and then acts appropriately

library(taxonomizr)

######
args = commandArgs(trailingOnly = TRUE)
sqldatabase = args[1]  # sqldatabase = "accessionTaxa.sql" 
acc = args[2] # acc = "NC_001538.1"   acc = "acc.txt"

if (!file.exists(sqldatabase)) {
  message("\nError: the first argument must be the accession2taxid SQL database file...exiting")
  quit()
}

if (is.na(acc)) {
  message("\nError: the second argument must be either an accession number of a file containing a list of accessions...exiting")
  quit()
}

#######

#message("TaxaSQL database is: ", sqldatabase)
#message("Accession is: ", acc)
if(file.exists(acc)) {
  #message("Getting lineage for accessions file ", acc)
  
  accfile = acc # save accfile name
  acc = read.table(acc)
  acc = acc[,1]

  taxids = accessionToTaxa(acc, sqldatabase)
  
  lineage = apply(getTaxonomy(taxids, sqldatabase), 1,
                  FUN=function (x) {paste(x,collapse="; ") } )
  
  toWrite = cbind(acc, taxids, lineage)
  lineagefile = paste0(accfile, "_withLineage.tsv")
  write.table(toWrite, lineagefile, sep="\t", quote=FALSE, row.names=FALSE)
  write(lineagefile, "")
} else {
  #message("Getting lineage for accession ", acc)
  taxid = accessionToTaxa(acc, sqldatabase)
  
  lineage = paste(getTaxonomy(taxid, "accessionTaxa.sql"), collapse="; ")
  
  write(paste(taxid, lineage, sep="\t"), "")
}

quit()


