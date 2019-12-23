#!/usr/bin/env python3

import argparse
import base64
import json
import loompy as lp
import numpy as np
import os
import pandas as pd
import scanpy as sc
import zlib

parser = argparse.ArgumentParser(description='')

parser.add_argument(
    "raw_filtered_data",
    type=argparse.FileType('r'),
    help='Input h5ad file containing the raw filtered data.'
)

parser.add_argument(
    "input",
    type=argparse.FileType('r'),
    help='Input h5ad file.'
)

parser.add_argument(
    "output",
    type=argparse.FileType('w'),
    help='Output h5ad file.'
)

parser.add_argument(
    '--nomenclature',
    type=str,
    dest="nomenclature",
    help='The name of the genome.'
)

parser.add_argument(
    '--scope-tree-level-1',
    type=str,
    dest="scope_tree_level_1",
    help='The name of the first level of the SCope tree.'
)

parser.add_argument(
    '--scope-tree-level-2',
    type=str,
    dest="scope_tree_level_2",
    help='The name of the second level of the SCope tree.'
)

parser.add_argument(
    '--scope-tree-level-3',
    type=str,
    dest="scope_tree_level_3",
    help='The name of the third level of the SCope tree.'
)

args = parser.parse_args()

# Define the arguments properly
FILE_PATH_IN = args.input
FILE_PATH_OUT_BASENAME = os.path.splitext(args.output.name)[0]


def dfToNamedMatrix(df):
    arr_ip = [tuple(i) for i in df.as_matrix()]
    dtyp = np.dtype(list(zip(df.dtypes.index, df.dtypes)))
    arr = np.array(arr_ip, dtype=dtyp)
    return arr


try:
    raw_filtered_adata = sc.read_h5ad(filename=args.raw_filtered_data.name)
    adata = sc.read_h5ad(filename=FILE_PATH_IN.name)
except IOError:
    raise Exception("Wrong input format. Expects .h5ad files, got .{}".format(os.path.splitext(FILE_PATH_IN)[0]))

ClusterMarkers_0 = pd.DataFrame(
    index=adata.raw.var.index,
    columns=[str(x) for x in range(max(set([int(x) for x in adata.obs['louvain']])) + 1)]
)

ClusterMarkers_0_avg_logFC = pd.DataFrame(
    index=adata.raw.var.index,
    columns=[str(x) for x in range(max(set([int(x) for x in adata.obs['louvain']])) + 1)]
)

ClusterMarkers_0_pval = pd.DataFrame(
    index=adata.raw.var.index,
    columns=[str(x) for x in range(max(set([int(x) for x in adata.obs['louvain']])) + 1)]
)

ClusterMarkers_0.fillna(0, inplace=True)
ClusterMarkers_0_avg_logFC.fillna(0, inplace=True)
ClusterMarkers_0_pval.fillna(0, inplace=True)

for i in range(max(set([int(x) for x in adata.obs['louvain']])) + 1):
    i = str(i)
    tot_genes = len(adata.uns['rank_genes_groups']['pvals_adj'][i])
    sigGenes = adata.uns['rank_genes_groups']['pvals_adj'][i] < 0.05
    deGenes = np.logical_and(np.logical_or(adata.uns['rank_genes_groups']['logfoldchanges'][i] >= 1.5,
                                           adata.uns['rank_genes_groups']['logfoldchanges'][i] <= -1.5),
                             np.isfinite(adata.uns['rank_genes_groups']['logfoldchanges'][i]))
    sigAndDE = np.logical_and(sigGenes, deGenes)
    names = adata.uns['rank_genes_groups']['names'][i][sigAndDE]
    ClusterMarkers_0.loc[names, i] = 1
    ClusterMarkers_0_avg_logFC.loc[names, i] = np.around(adata.uns['rank_genes_groups']['logfoldchanges'][i][sigAndDE],
                                                         decimals=6)
    ClusterMarkers_0_pval.loc[names, i] = np.around(adata.uns['rank_genes_groups']['pvals_adj'][i][sigAndDE],
                                                    decimals=6)

metaJson = {}
metaJson["metrics"] = []
metaJson["annotations"] = []

main_dr = pd.DataFrame(adata.obsm['X_umap'], columns=['_X', '_Y'])

metaJson['embeddings'] = [
    {
        "id": -1,
        "name": f"HVG UMAP"
    }
]

Embeddings_X = pd.DataFrame()
Embeddings_Y = pd.DataFrame()

embeddings_id = 1

if 'X_tsne' in adata.obsm.keys():
    Embeddings_X[str(embeddings_id)] = pd.DataFrame(adata.obsm['X_tsne'])[0]
    Embeddings_Y[str(embeddings_id)] = pd.DataFrame(adata.obsm['X_tsne'])[1]
    metaJson['embeddings'].append(
        {
            "id": embeddings_id,
            "name": f"HVG t-SNE"
        }
    )
    embeddings_id += 1

Embeddings_X[str(embeddings_id)] = pd.DataFrame(adata.obsm['X_pca'])[0]
Embeddings_Y[str(embeddings_id)] = pd.DataFrame(adata.obsm['X_pca'])[1]
metaJson['embeddings'].append(
    {
        "id": embeddings_id,
        "name": f"HVG PC1/PC2"
    }
)

metaJson["clusterings"] = [
    {
        "id": 0,
        "group": "Louvain",
        "name": "Louvain default resolution",
        "clusters": [],
        "clusterMarkerMetrics": [
            {
                "accessor": "avg_logFC",
                "name": "Avg. logFC",
                "description": "Average log fold change from Wilcox test"
            }, {
                "accessor": "pval",
                "name": "Adjusted P-Value",
                "description": "Adjusted P-Value from Wilcox test"
            }
        ]
    }
]

for i in range(max(set([int(x) for x in adata.obs['louvain']])) + 1):
    clustDict = {}
    clustDict['id'] = i
    clustDict['description'] = f'Unannotated Cluster {i}'
    metaJson['clusterings'][0]['clusters'].append(clustDict)

clusterings = pd.DataFrame()

clusterings["0"] = adata.obs['louvain'].values.astype(np.int64)

col_attrs = {
    "CellID": np.array(adata.obs.index),
    "Embedding": dfToNamedMatrix(main_dr),
    "Embeddings_X": dfToNamedMatrix(Embeddings_X),
    "Embeddings_Y": dfToNamedMatrix(Embeddings_Y),
    "Clusterings": dfToNamedMatrix(clusterings),
    "ClusterID": np.array(adata.obs['louvain'].values)
}

for col in adata.obs.keys():
    if type(adata.obs[col].dtype) == pd.core.dtypes.dtypes.CategoricalDtype:
        metaJson["annotations"].append(
            {
                "name": col,
                "values": list(set(adata.obs[col].values))
            }
        )
    else:
        metaJson["metrics"].append(
            {
                "name": col
            }
        )
    col_attrs[col] = np.array(adata.obs[col].values)

row_attrs = {
    "Gene": np.array(adata.raw.var.index),
    "ClusterMarkers_0": dfToNamedMatrix(ClusterMarkers_0),
    "ClusterMarkers_0_avg_logFC": dfToNamedMatrix(ClusterMarkers_0_avg_logFC),
    "ClusterMarkers_0_pval": dfToNamedMatrix(ClusterMarkers_0_pval)
}

attrs = {"MetaData": json.dumps(metaJson)}

attrs['MetaData'] = base64.b64encode(zlib.compress(json.dumps(metaJson).encode('ascii'))).decode('ascii')
attrs["Genome"] = '' if args.nomenclature is None else args.nomenclature
attrs["SCopeTreeL1"] = 'Unknown' if args.scope_tree_level_1 is None else args.scope_tree_level_1
attrs["SCopeTreeL2"] = '' if args.scope_tree_level_2 is None else args.scope_tree_level_2
attrs["SCopeTreeL3"] = '' if args.scope_tree_level_3 is None else args.scope_tree_level_3

lp.create(
    filename=f"{FILE_PATH_OUT_BASENAME}.loom",
    layers=(raw_filtered_adata.X).T,
    row_attrs=row_attrs,
    col_attrs=col_attrs,
    file_attrs=attrs
)
