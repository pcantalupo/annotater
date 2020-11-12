# BLAST database (3 seqs)

1. SV40 TAg bp1-250 (gi 15)
2. SV40 TAg bp550-708 (gi 16)
3. HPV16 E6 gi|970757575|gb|KP965141.1|

The first two seqs have different GIs but have same taxid 10633. The 10633
taxid is in Reann's t/data/gi_taxid_nucl.bin file with the fake gis 15 and
16 (I had to use fake GIs since the real ones are large numbers that kept
crashing Gi2taxid when I tried to make the BIN files).

The 3rd GI (970757575) is not found in Reann's gi_taxid_nucl file so this
will test Reann's ability to get the lineage remotely.



# Query sequences (5 seqs)

LTAg1 bp1-200 genomic - will hit GI 15

LTAg2 bp50-250 genomic - will hit GI 15
LocalTaxonomy should not have to lookup this taxid nor lineage since it will
have that info saved in hash

LTAg3 bp2224-2473 genomic - will hit GI 16
LocalTaxonomy will have to get taxid but then should not have to get lineage
since it will be stored in taxid2lineage hash

HPV16E6.1 bp1-280 of KP965141.1 - will hit GI 970757575
LocalTaxonomy won't find taxid since there is no entry for this GI in
Reann's gi_taxid_nucl BIN file. LocalTax will have to get lineage remotely.

HPV16E6.2 bp281-560 - will hit GI 970757575
LocalTaxonomy won't find a gi2taxid mapping but there will be a gi2lineage
mapping so no local nor remote taxonomy queries will need to be made



# Reann command line

Reann.pl -file seqs.fa -config annotater.config -num_threads 1 -evalue 1e-5 -tax


