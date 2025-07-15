
// Log messages to terminal
println "Command line           : $workflow.commandLine"
println "Project dir            : $workflow.projectDir"
println "Fasta file             : $params.fasta"
println "Annotater config file  : $params.config"

println "\nBelow are global parameter settings that might be overridden in the Annotater config file"
println "Global evalue          : $params.evalue"
println "Global query coverage  : $params.qc"
println "Global % identity      : $params.pid"
println "\n"

workflow {
  if (params.fasta == null || params.config == null) {
      exit 1, """
      ERROR: Missing input parameters.
      Please provide the path to your FASTA sequence file (--fasta)
      and your configuration file (--config).

      Usage:
      nextflow run main.nf --fasta sequences.fasta --config config.txt
      """
  }
  fasta_ch = Channel.fromPath(params.fasta)
  config_ch = Channel.fromPath(params.config)

  // Validate taxonomy parameters
  // if --tax was set and --remotetax was not, need to specify --taxasql, --nodesdmp, and --namesdmp 
  if (params.tax && !params.remotetax && 
      (params.taxasql == null || params.nodesdmp == null || params.namesdmp == null) ) {
      exit 1, "When using --tax param, the --taxasql, --nodesdmp and --namesdmp params must be provided."
  }

  ANNOTATER(fasta_ch, config_ch)
}

process ANNOTATER {
  tag "${fasta_file.simpleName}"

  container "${ workflow.containerEngine == 'singularity' ?
                  'docker://virushunter/annotater' :
                  'virushunter/annotater' }"

  input:
  path fasta_file    // The input FASTA sequence file
  path config_file   // The configuration file for Reann.pl

  output:
  path "${params.outdir}/ann*"
  path "${params.outdir}/*txt"
  path "${params.outdir}/*log*"

  publishDir "$params.pipeline_outdir/", mode: 'copy'

  script:
  """
  if [ "${params.tax}" = "true" ] && [ "${params.remotetax}" = "false" ]; then
    export TAXASQL="${params.taxasql}"
    export NAMESDMP="${params.namesdmp}"
    export NODESDMP="${params.nodesdmp}"
  fi

  Reann.pl \\
      -file "${fasta_file.name}" \\
      -config "${config_file.name}" \\
      -num_threads ${task.cpus} \\
      ${params.evalue  ? "-evalue ${params.evalue}"   : ''} \\
      ${params.outdir  ? "-folder ${params.outdir}"   : ''} \\
      ${params.tax ? '-tax' : ''} \\
      ${params.remotetax ? '-remotetax' : ''} \\
      ${params.qc  ? "-qc ${params.qc}"   : ''} \\
      ${params.pid ? "-pid ${params.pid}" : ''}

  cp .command.out ${params.outdir}/log.out
  cp .command.err ${params.outdir}/log.err
  """
}
