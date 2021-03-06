nextflow.preview.dsl=2

//////////////////////////////////////////////////////
//  Import sub-workflows from the modules:

include '../src/utils/processes/utils.nf' params(params)

include QC_FILTER from '../src/scanpy/workflows/qc_filter.nf' params(params)
include NORMALIZE_TRANSFORM from '../src/scanpy/workflows/normalize_transform.nf' params(params)
include HVG_SELECTION from '../src/scanpy/workflows/hvg_selection.nf' params(params)
include SC__SCANPY__REGRESS_OUT from '../src/scanpy/processes/regress_out.nf' params(params)
include NEIGHBORHOOD_GRAPH from '../src/scanpy/workflows/neighborhood_graph.nf' params(params)
include DIM_REDUCTION_PCA from '../src/scanpy/workflows/dim_reduction_pca.nf' params(params)
include '../src/scanpy/workflows/dim_reduction.nf' params(params)
include '../src/scanpy/processes/cluster.nf' params(params)
include CLUSTER_IDENTIFICATION from '../src/scanpy/workflows/cluster_identification.nf' params(params)
include SC__H5AD_TO_FILTERED_LOOM from '../src/utils/processes/h5adToLoom.nf' params(params)
include FILE_CONVERTER from '../src/utils/workflows/fileConverter.nf' params(params)

// reporting:
include UTILS__GENERATE_WORKFLOW_CONFIG_REPORT from '../src/utils/processes/reports.nf' params(params)
include SC__SCANPY__MERGE_REPORTS from '../src/scanpy/processes/reports.nf' params(params)
include SC__SCANPY__REPORT_TO_HTML from '../src/scanpy/processes/reports.nf' params(params)

workflow single_sample {

    take:
        data

    main:
        // run the pipeline
        out = SC__FILE_CONVERTER( data )
        if(params.sc.scanpy.containsKey("filter")) {
            out = QC_FILTER( out ).filtered // Remove concat
        }
        if(params.sc.scanpy.containsKey("data_transformation") && params.sc.scanpy.containsKey("normalization")) {
            out = NORMALIZE_TRANSFORM( out )
        }
        out = HVG_SELECTION( out )
        if(params.sc.scanpy.containsKey("regress_out")) {
            out = SC__SCANPY__REGRESS_OUT( out.scaled )
        } else {
            out = out.scaled
        }
        DIM_REDUCTION_PCA( out )
        NEIGHBORHOOD_GRAPH( DIM_REDUCTION_PCA.out )
        DIM_REDUCTION_TSNE_UMAP( NEIGHBORHOOD_GRAPH.out )
        CLUSTER_IDENTIFICATION(
            NORMALIZE_TRANSFORM.out,
            DIM_REDUCTION_TSNE_UMAP.out.dimred_tsne_umap,
            "No Batch Effect Correction"
        )

        // Conversion
        // Convert h5ad to X (here we choose: loom format)
        if(params.sc.scanpy.containsKey("filter")) {
            filteredloom = SC__H5AD_TO_FILTERED_LOOM( QC_FILTER.out.filtered )
            // In parameter exploration mode, this automatically merge all the results into the resulting loom
            scopeloom = FILE_CONVERTER(
                CLUSTER_IDENTIFICATION.out.marker_genes.groupTuple(),
                'loom',
                QC_FILTER.out.filtered
            )
        } else {
            filteredloom = SC__H5AD_TO_FILTERED_LOOM( SC__FILE_CONVERTER.out )
            scopeloom = FILE_CONVERTER(
                CLUSTER_IDENTIFICATION.out.marker_genes.groupTuple(),
                'loom',
                SC__FILE_CONVERTER.out
            )
        }

        // Publishing
        SC__PUBLISH_H5AD( 
            CLUSTER_IDENTIFICATION.out.marker_genes.map { 
                it -> tuple(it[0], it[1], null)
            },
            params.global.project_name+".single_sample.output"
        )

        samples = data.map { it -> it[0] }
        UTILS__GENERATE_WORKFLOW_CONFIG_REPORT(
            file(workflow.projectDir + params.utils.workflow_configuration.report_ipynb)
        )

        // Reporting:
        def clusteringParams = SC__SCANPY__CLUSTERING_PARAMS( clean(params.sc.scanpy.clustering) )
        ipynbs = QC_FILTER.out.report.map {
            it -> tuple(it[0], it[1])
        }.mix(
            samples.combine(UTILS__GENERATE_WORKFLOW_CONFIG_REPORT.out),
            HVG_SELECTION.out.report.map {
                it -> tuple(it[0], it[1])
            },
            DIM_REDUCTION_TSNE_UMAP.out.report.map {
                it -> tuple(it[0], it[1])
            }
        ).groupTuple().map {
            it -> tuple(it[0], *it[1])
        }.join(
            CLUSTER_IDENTIFICATION.out.report,
            by: 0
        )

        if(!clusteringParams.isParameterExplorationModeOn()) {
            ipynbs = ipynbs.map {
                it -> tuple(it[0], it[1..it.size()-2], null)
            }
        } else {
            ipynbs = ipynbs.map {
                it -> tuple(it[0], it[1..it.size()-2], it[it.size()-1])
            }
        }

        SC__SCANPY__MERGE_REPORTS(
            ipynbs,
            "merged_report",
            clusteringParams.isParameterExplorationModeOn()
        )
        SC__SCANPY__REPORT_TO_HTML(SC__SCANPY__MERGE_REPORTS.out)

    emit:
        filteredloom
        scopeloom

}
