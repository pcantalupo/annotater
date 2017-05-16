# annotater

Got sequences that need annotated with various BLAST programs? Look no further.

## Dependencies

Install the following and make sure they are working before proceeding:

+ [Bioperl](http://bioperl.org/)
+ Perl modules
    + XML::Simple
    + Bio::LITE::Taxonomy
    + Bio::LITE::Taxonomy::NCBI
    + Bio::LITE::Taxonomy::NCBI::Gi2taxid
+ [BLAST+](https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/)
    + If you are going to put your BLAST databases in a single folder, add that directory to your `BLASTDB` variable.

## Installation

Clone repository. Add the `annotater` directory path to your `PATH` and `PERL5LIB` variables. In addition, add `annotater/bin` directory path to your `PATH` variable.

Do not use a tilde (~) in the path that you set for your environmental variable `BLASTDB`; it must be a full path.

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

