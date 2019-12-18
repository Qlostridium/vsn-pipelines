nextflow.preview.dsl=2

if(!params.containsKey("test")) {
  	binDir = "${workflow.projectDir}/src/scanpy/bin/"
} else {
  	binDir = ""
}

process SC__SCANPY__MARKER_GENES {

  	container params.sc.scanpy.container
  	clusterOptions "-l nodes=1:ppn=2 -l pmem=30gb -l walltime=1:00:00 -A ${params.global.qsubaccount}"
  	publishDir "${params.global.outdir}/data/intermediate", mode: 'symlink', overwrite: true
  
  	input:
		// Expects 
		// - normalizedTransformedData to be an AnnData containing log normalised data
    	tuple val(sampleId), path(normalizedTransformedData), path(clusteredData)
  
  	output:
    	tuple val(sampleId), path("${sampleId}.SC__SCANPY__MARKER_GENES.${processParams.off}")
  
  	script:
    	def sampleParams = params.parseConfig(sampleId, params.global, params.sc.scanpy.marker_genes)
		processParams = sampleParams.local
		"""
		${binDir}cluster/sc_marker_genes.py \
			${(processParams.containsKey('method')) ? '--method ' + processParams.method : ''} \
			${(processParams.containsKey('groupby')) ? '--groupby ' + processParams.groupby : ''} \
			${(processParams.containsKey('ngenes')) ? '--ngenes ' + processParams.ngenes : ''} \
			$normalizedTransformedData \
			$clusteredData \
			"${sampleId}.SC__SCANPY__MARKER_GENES.${processParams.off}"
		"""

}
