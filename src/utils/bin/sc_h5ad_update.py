#!/usr/bin/env python3

import os
import sys
import argparse
import pandas as pd
import scanpy as sc
import numpy as np

parser = argparse.ArgumentParser(description='')

parser.add_argument(
    "input",
    type=argparse.FileType('r'),
    help='The path to the input h5ad file '
)

parser.add_argument(
    "output",
    type=argparse.FileType('w'),
    help='The path to the updated h5ad output'
)

parser.add_argument(
    '-p', "--x-pca",
    type=argparse.FileType('r'),
    dest="x_pca",
    required=False,
    help='The path the (compressed) TSV file containing the new PCA embeddings.'
)

args = parser.parse_args()

FILE_PATH_IN = args.input.name
FILE_PATH_OUT_BASENAME = os.path.splitext(args.output.name)[0]

# I/O
# Expects h5ad file
try:
    adata = sc.read_h5ad(filename=FILE_PATH_IN)
except IOError:
    raise Exception("Can only handle .h5ad files.")

#
# Update the feature/observation-based metadata with all the columns present within the look-up table.
#

if args.x_pca is not None:
    print("Updating X_pca slot of the given AnnData...")
    x_pca = pd.read_csv(
        filepath_or_buffer=args.x_pca,
        sep="\t",
        index_col=0
    ).values
    adata.obsm["X_pca"] = x_pca
    adata.uns["harmony"] = {
        "computed": True,
        "location": "AnnData.obsm['X_pca']"
    }


# I/O
adata.write_h5ad("{}.h5ad".format(FILE_PATH_OUT_BASENAME))
