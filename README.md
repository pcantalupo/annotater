# annotater

Got sequences that need annotated with various BLAST programs? Look no further.

## Dependencies

Install the following and make sure they are working before proceeding:

+ [Bioperl](http://bioperl.org/)
+ Perl modules
    + Bio::DB::EUtilities
    + XML::Simple
    + Bio::LITE::Taxonomy
    + Bio::LITE::Taxonomy::NCBI
    + Bio::LITE::Taxonomy::NCBI::Gi2taxid
+ [NCBI Taxonomy database](https://ftp.ncbi.nih.gov/pub/taxonomy)
+ [BLAST+ >= 2.6.0](https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/)
    + If you are going to put your BLAST databases in a single folder, add that directory to your `BLASTDB` variable.

## Installation

Clone repository. Add the `annotater` directory path to your `PATH` and `PERL5LIB` variables. In addition, add `annotater/bin` directory path to your `PATH` variable. Set a `BLASTDB` environmental variable using a full path to the location of your BLAST databases (tilde `~` is not allowed in the path). All the BLAST databases need to be in the same folder unless you specify full paths in the configuration file.

### NCBI Taxonomy database

Get the Taxonomy files
```
wget --quiet ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/gi_taxid_nucl.dmp.gz &
wget --quiet ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/gi_taxid_prot.dmp.gz &
wget --quiet ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz &
wget --quiet ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxcat.tar.gz &
```

Unzip each GZ file
`for file in *gz; do echo $file; gunzip $file; done`

Untar the tar archives
```
tar xvf taxcat.tar
tar xvf taxdump.tar
```

Convert DMP file to BIN file for Bio::LITE::Taxonomy::NCBI::Gi2taxid module.
See https://github.com/pcantalupo/mytaxonomy
`makebin.pl &`

Then set the following environmental variables:
1. `NGT` - full path to the gi_taxid_nucl dictionary that was created with the Bio::LITE::Taxonomy::NCBI::Gi2taxid module
2. `PGT` - same as `NGT` but to the protein dictionary file
3. `NAMESDMP` and `NODESDMP` - full path to names.dmp and nodes.dmp, respectively

## Output

The annotated output file is `./annotater/ann.wTax.BE.report.txt`. The description of the fields is as follows:
1. seqID - sequence identifier
2. seq - sequence
3. seqLength - sequence length
4. pid - Percent identity of the alignment
5. coverage - Percent of the query that participates in the alignment
6. e - Evalue of the alignment
7. accession - the accession number of the subject (a.k.a. hit) sequence in the database (see Column ‘db’).
8. desc - the description of the subject sequence
9. type - the taxonomic bin of the subject sequence. Possible values: virus (meaning eukaryotic viruses), phage, bacteria, human, mouse, fungi, and other. 
10. family - the virus family
11. species - the species name of the subject
12. genome - the genome type of the virus 
13. algorithm - the search algorithm used for this alignment
14. db - the database used by the algorithm to search for an alignment of the contig
15. qstart - the starting base in the query that participates in the alignment
16. qend - the ending base in the query that participates in the alignment
17. sstart - the starting base in the subject that participates in the alignment
18. send - the ending base in the subject that participates in the alignment
19. nsf - non-stop frame. If the value is 1, there is at least one frame in the contig that does not have a stop-codon.
20. qent - nucleotide entropy of the query
21. qhsp_ent - nucleotide entropy of the query sequence from Qstart to Qend, inclusive
22. shsp_ent - nucleotide entropy of the subject sequence from Sstart to Send, inclusive
23. shsp_%lc - percent of low complexity amino acids in the subject sequence from Sstart to Send, inclusive

## Developer info

### Reann->new()
1. creates output folder
2. copies fasta file to output folder and creates temporary sequence chunk files (named ann.X.fasta [X = 0 to N - 1 where N = num chunks] )
3. copies configuration file to output folder
4. writes version.txt file

### Reann->run()
1. Writes/updates restart.txt file
2. generates a program (i.e. blast) outputfile for each step of pipeline for each sequence file chunk
3. removes temporary sequence chunk files (ann.X.fasta)

### Reann->Report()
1. creates ann.report.txt file
2. removes fasta file that was copied into output folder

### Reann->Taxonomy()
1. TBD

### Configuration file

Line 122 - config file is removed. Remove this line so config file is kept in the output folder.

### Restart file

The Restart file defines the step that finished. The first value is the sequence file chunk (0-based). The second value is the step of pipeline (0-based). Each step is defined on one line in the annotator config file.

For example, if restart = 0,1 then this means that Step 2 of the first sequence file chunk finished and that Step 3 (0,2) needs to be run next. However, there are two exceptions to this rule:

1. At the start of Reann->run(), a restart file is written that contains 0,0 which may seem like it means that Chunk 1/Step 1 finished. However, Step 1 still needs run and after it runs, the restart file is rewritten with 0,0 to indicate that Chunk 1/Step 1 is finished.
2. At end of Reann->run(), the restart file is rewritten with value of X,0 where X is equal to number of Fasta chunks + 1.

Let’s look at an example where there are three annotation steps. The restart file will look like the following before (line 109) and after (line 111) each step.

| Step | Beginning | End  |
| ---- | --------- | ---- |
| 1  | 0,0 | 0,0 |
| 2  | 0,0 | 0,1 |
| 3  | 0,1 | 0,2 |
