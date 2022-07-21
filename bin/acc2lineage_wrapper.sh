#!/bin/bash

# These environment variables must be set:
# 1. TAXASQL - path to the accessionTaxa.sql database (taxonomizr R package)
# 2. TAXASQL_NAMESDMP - path to the names.dmp taxonomy file
# 3. TAXASQL_NODESDMP - path to the nodes.dmp taxonomy file

set -euo pipefail
module purge && module load gcc/10.2.0 r/4.2.0

acc=$1

ln -sf $TAXASQL
ln -sf $TAXASQL_NAMESDMP
ln -sf $TAXASQL_NODESDMP

acc2lineage.R $TAXASQL "$acc"

exit 0


