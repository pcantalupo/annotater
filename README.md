# annotater

Got sequences that need annotated with various BLAST programs? [Diamond](https://github.com/bbuchfink/diamond) and [Rapsearch2](http://omics.informatics.indiana.edu/mg/RAPSearch2/) are supported also.

## Quick Start

```
perl Makefile.PL
make
make test
make install
```

If you encounter errors check below for the necessary dependencies that are required.

Run annotater: `Reann.pl -file YOURSEQUENCES.FA -config CONFIGFILE -tax -remotetax`. These options tell annotater to search your sequences against the list of searches in your configuration file and to lookup taxonomy information (`-tax`) for subject hits by querying NCBI (`-remotetax`). Your results are found in `annotator/ann.wTax.BE.report.txt` (tab-delimited text).

## Installation

Install the following and make sure they are working before proceeding:

+ [Bioperl](http://bioperl.org/)
+ Perl modules
    + Bio::DB::EUtilities
    + LWP::UserAgent
    + XML::Simple
+ [BLAST+ >= 2.13.0](https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/)
    + If you are going to put your BLAST databases in a single folder, add that directory to your `BLASTDB` variable.
+ [Diamond >= 2.0.15](https://github.com/bbuchfink/diamond) (optional)
+ [Rapsearch2 >= 2.24](https://sourceforge.net/projects/rapsearch2/files/) (optional)
    + I had trouble compiling Rapsearch2 and was getting weird evalues (issues [here](https://github.com/zhaoyanswill/RAPSearch2/issues/37#issuecomment-342584855) and [here](https://github.com/zhaoyanswill/RAPSearch2/issues/29#issuecomment-342583203))
    + Due to the above issues, I use Diamond instead of Rapsearch2
+ [NCBI Taxonomy database](https://ftp.ncbi.nih.gov/pub/taxonomy) (optional)
    + Build a local taxonomy database using [taxonomizr](https://github.com/sherrillmix/taxonomizr)

Clone repository. Add the `annotater` directory path to your `PATH` and `PERL5LIB` variables. In addition, add `annotater/bin` directory path to your `PATH` variable. Set a `BLASTDB` environmental variable using a full path to the location of your BLAST databases (tilde `~` is not allowed in the path). All the BLAST databases need to be in the same folder unless you specify full paths in the configuration file.

## Configuration

Annotater requires two input files: a fasta file and a configuration file. There are example configuration files in `./configs`. Let's take a look at `./configs/annot.conf`.

```
-exec blastn -db GCF_000001405.39_top_level -qc 50 -pid 80 -lcase_masking -max_target_seqs 2
-exec blastn -db nt -qc 50 -pid 80
-exec blastx -db nr -task blastx-fast
-exec tblastx -db ref_viruses_rep_genomes
```

Each line specifies a different Search, either a blast program (`blastn`, `tblastx`), `diamond` or `rapsearch`, with its associated parameters. The searches are run in serial fashion starting from the top. Each line must start with `-exec` to tell Annotater which search program to run. Currently only BLAST+, `diamond` and `rapsearch` are supported. The options `-qc`, query coverage, and `-pid`, percent identity, are specific to Annotater. Query coverage and percent identity specifies the minimum % query coverage and % identity for a hit to be significant. The remaining parameters are specific to each search program; check the appropriate documentation for available options.

## Usage

Lets annotate the following sequence file `e7.fa` (the E7 gene from [HPV16](https://www.ncbi.nlm.nih.gov/nuccore/NC_001526.2)) with Annotater against the NCBI reference virus genomes.

```
>e7
atgcatggagatacacctacattgcatgaatatatgttagatttgcaaccagagacaactgatctctactgttatgagcaattaaatgacagctcagaggaggaggatgaaatagatggtccagctggacaagcagaaccggacagagcccattacaatattgtaaccttttgttgcaagtgtgactctacgcttcggttgtgcgtacaaagcacacacgtagacattcgtactttggaagacctgttaatgggcacactaggaattgtgtgccccatctgttctcagaaaccataa
```

Then download the [reference virus genomes BLAST database](https://ftp.ncbi.nlm.nih.gov/blast/db/ref_viruses_rep_genomes.tar.gz) and extract it. Next, create a configuration file called `config.txt` that contains:

```
-exec blastn -db /PATH/TO/ref_viruses_rep_genomes
```

You have to specify a full path to the database file unless you place the database files in your `$BLASTDB` directory. Then run Annotater with 4 threads and set an evalue cutoff of 1e-50.

`Reann.pl -file e7.fa -config config.txt -num_threads 4 -evalue 1e-50`

Options such as `-num_threads` and `-evalue` will be applied to each Search in the configuration file.  The results are found in the file `./annotater/ann.wTax.BE.report.txt`. The fields and their descriptions are: 

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

### Taxonomy module
In the `e7.fa` example above, notice that columns 9 to 12 are `NULL` in the `report.txt` file. This is because we didn't tell Annotater to run the Taxonomy module. If you want taxonomy information about each subject such as type (i.e. bacteria, virus, etc...), virus family, species, genome type (i.e. ssRNA+, etc...), rerun the Annotater command line but this time add the parameter `-tax`. However, if you don't have a local NCBI Taxonomy database properly installed (see below), add the option `-remotetax` as well (this query NCBI for taxonomy info). Since Annotater kept track of what searches were completed, it will skip running BLASTN again on the sequence and start immediately on determining the taxonomy information. 

`Reann.pl -file e7.fa -config config.txt -num_threads 4 -evalue 1e-50 -tax`

### NCBI Taxonomy database (optional)

Build a local copy of the [NCBI Taxonomy database](https://ftp.ncbi.nih.gov/pub/taxonomy/accession2taxid/) using the `taxonomizr` R package ([Github](https://github.com/sherrillmix/taxonomizr)). Run the following R commands (takes several hours and about 150GB of space):

```
library(taxonomizr)
prepareDatabase('accessionTaxa.sql', types = c('nucl_gb', 'nucl_wgs', 'prot'))
```

This will download the necessary NCBI Taxonomy files and create a file called `accessionTaxa.sql`. Then set the following environmental variables:
1. `TAXASQL` - path to `accessionTaxa.sql`
2. `NAMESDMP` and `NODESDMP` - full path to names.dmp and nodes.dmp, respectively

### Running Annotater with Docker

You can build your own docker image by running `docker build -t annotater .` or you can download the annotater image from Docker Hub with `docker pull virushunter/annotater`

To run Annotater using the `e7.fa` example above, use the following command line but make sure to change the `/PATH/TO/BLASTDIR` as appropriate for your setup.

`docker run --rm -ti -v $(pwd):$(pwd) -v /PATH/TO/BLASTDIR:/PATH/TO/BLASTDIR -w $(pwd) virushunter/annotater Reann.pl -file e7.fa -config config.txt -num_threads 4 -evalue 1e-50`

If you want to run the Taxonomy module, you need to add a volume mount for your taxonomy directory that contains `accessionTaxa.sql`. Also, you need to set the environment variables pointing to the location of the taxonomy files. Here is the complete docker command (make sure to change the directory paths to match your setup)

```
docker run --rm -ti -v $(pwd):$(pwd) -v /PATH/TO/BLASTDIR:/PATH/TO/BLASTDIR \
-v /PATH/TO/TAXONOMYDIR:/PATH/TO/TAXONOMYDIR \
-w $(pwd) \
-e TAXASQL=/PATH/TO/TAXONOMYDIR/accessionTaxa.sql \
-e NAMESDMP=/PATH/TO/TAXONOMYDIR/names.dmp \
-e NODESDMP=/PATH/TO/TAXONOMYDIR/nodes.dmp \
virushunter/annotater Reann.pl -file e7.fa -config config.txt -num_threads 4 -evalue 1e-50
```

### Using Diamond

In order to use Diamond, you need to add the `-type` parameter in the configuration file. For instance, if you want to run `diamond blastx`, add something like the following in your config file:

```
-exec diamond -type blastx -d /PATH/TO/nr.dmnd
```


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


## Deprecated

### NCBI Taxonomy database (old)

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
1. `NGT` - full path to the gi_taxid_nucl .bin file that was created with the Bio::LITE::Taxonomy::NCBI::Gi2taxid module
2. `PGT` - same as `NGT` but to the gi_taxid_prot .bin file
3. `NAMESDMP` and `NODESDMP` - full path to names.dmp and nodes.dmp, respectively



