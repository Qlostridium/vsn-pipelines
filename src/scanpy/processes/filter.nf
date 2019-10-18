nextflow.preview.dsl=2

include getBaseName from '../../utils/processes/files.nf'

process SC__SCANPY__COMPUTE_QC_STATS {

  container params.sc.scanpy.container

  input:
    file(f)
  output:
    file "${getBaseName(f)}.SC__SCANPY__COMPUTE_QC_STATS.${params.off}"
  script:
    """
    ${workflow.projectDir}/src/scanpy/bin/filter/sc_compute_qc_stats.py \
      ${(params.containsKey('cellFilterMinNGenes')) ? '--min-n-genes ' + params.cellFilterMinNGenes : ''} \
      ${(params.containsKey('cellFilterMaxNGenes')) ? '--max-n-genes ' + params.cellFilterMaxNGenes : ''} \
      ${(params.containsKey('cellFilterMaxPercentMito')) ? '--max-percent-mito ' + params.cellFilterMaxPercentMito : ''} \
      ${(params.containsKey('geneFilterMinNCells')) ? '--min-number-cells ' + params.geneFilterMinNCells : ''} \
      $f \
      "${getBaseName(f)}.SC__SCANPY__COMPUTE_QC_STATS.${params.off}"
    """
}

process SC__SCANPY__GENE_FILTER {

  container params.sc.scanpy.container
  publishDir "${params.outdir}/data", mode: 'symlink'

  input:
    file(f)
  output:
    file "${getBaseName(f)}.SC__SCANPY__GENE_FILTER.${params.off}"
  script:
    """
    ${workflow.projectDir}/src/scanpy/bin/filter/sc_gene_filter.py \
      ${(params.containsKey('geneFilterMinNCells')) ? '--min-number-cells ' + params.geneFilterMinNCells : ''} \
      $f \
      "${getBaseName(f)}.SC__SCANPY__GENE_FILTER.${params.off}"
    """
}

process SC__SCANPY__CELL_FILTER {

  container params.sc.scanpy.container
  publishDir "${params.outdir}/data", mode: 'symlink'

  input:
    file(f)
  output:
    file "${getBaseName(f)}.SC__SCANPY__CELL_FILTER.${params.off}"
  script:
    """
    ${workflow.projectDir}/src/scanpy/bin/filter/sc_cell_filter.py \
        ${(params.containsKey('cellFilterMinNCounts')) ? '--min-n-counts ' + params.cellFilterMinNCounts : ''} \
        ${(params.containsKey('cellFilterMaxNCounts')) ? '--max-n-counts ' + params.cellFilterMaxNCounts : ''} \
        ${(params.containsKey('cellFilterMinNGenes')) ? '--min-n-genes ' + params.cellFilterMinNGenes : ''} \
        ${(params.containsKey('cellFilterMaxNGenes')) ? '--max-n-genes ' + params.cellFilterMaxNGenes : ''} \
        ${(params.containsKey('cellFilterMaxPercentMito')) ? '--max-percent-mito ' + params.cellFilterMaxPercentMito : ''} \
        $f \
        "${getBaseName(f)}.SC__SCANPY__CELL_FILTER.${params.off}"
    """
}

