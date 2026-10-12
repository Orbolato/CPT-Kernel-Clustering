# Kernel k-means and kernel X-means for CPT soil classification

Public R implementation and recovered source lineage associated with:

**Lucas Orbolato Carvalho and Dimas Betioli Ribeiro, “Application of kernel k-means and kernel x-means clustering to obtain soil classes from cone penetration test data,” _Soils and Rocks_, 43(4), 607–618, 2020.**

- DOI: https://doi.org/10.28927/SR.434607
- Repository: https://github.com/Orbolato/CPT-Kernel-Clustering

## What the paper does

The study applies unsupervised kernel clustering to four directly measured cone penetration test (CPT) quantities: depth, cone resistance, sleeve friction, and pore pressure. Two related analyses are reported:

- **Full dataset:** 130,966 measurements from 179 CPT soundings. Gaussian kernel k-means is evaluated for 7–10 clusters, with 9 clusters selected in the paper.
- **Specific dataset:** 2,847 measurements from five CPT soundings paired with SPT information. Kernel X-means starts from two clusters and uses a Bayesian information criterion (BIC) split test; the paper reports four resulting classes.

Artificial neural networks (ANNs) are then used to evaluate how reproducibly the derived cluster labels can be learned from four-input and three-input CPT feature sets using 10-fold evaluation.

### Published ANN benchmarks

These values are reported by the article and are provided as reference benchmarks rather than assertions that every modern rerun will match them exactly.

| Study | Inputs | Mean class recall | SD |
| --- | --- | ---: | ---: |
| Full | depth + cone resistance + sleeve friction + pore pressure | 89.35% | 0.40% |
| Full | depth + cone resistance + sleeve friction | 84.47% | 0.30% |
| Specific | depth + cone resistance + sleeve friction + pore pressure | 97.04% | 1.24% |
| Specific | depth + cone resistance + sleeve friction | 90.37% | 2.48% |

## Recovery and cleanup status

The source used to build this repository was recovered from an author archive named `Não supervisionado.zip`. Most files are dated in 2018, while the article was submitted in 2020. The recovered material is clearly the development lineage of the paper, but it is **not a self-contained final-paper software package**.

The recovered scripts include:

- absolute Windows paths;
- dependence on objects created in an earlier interactive R session;
- references to `conf.csv` and `conf_2.csv`, which are not present in the archive;
- commented exploratory branches alongside active analysis code;
- system-time random seeds in the ANN balancing procedure;
- a modified third-party `xmeans.R` implementation with no explicit redistribution license in the recovered file.

For that reason, this repository separates **provenance preservation** from **maintained code**:

- exact author-origin development scripts are preserved in a source-only archive under `legacy/2018/`;
- the third-party `xmeans.R` file is documented by checksum but is not redistributed;
- maintained R code removes hard-coded paths, makes random seeds explicit, separates reusable functions from command-line entry points, and uses US English comments/documentation;
- the recovered datasets are not published because redistribution rights are not established.

See [`legacy/2018/README.md`](legacy/2018/README.md) for hashes and provenance details.

## Important preprocessing note

The article states that the clustering uses the four original measured CPT variables and that distance-based clustering requires normalization. It does not fully specify the numerical scaling formula used in the clustering implementation. The recovered 2018 source applies:

1. feature-wise min-max scaling; then
2. the signed mapping

```text
sign(t) * log10(1 + (10^2 - 1) * abs(t)) / 2
```

The cleaned runners therefore expose preprocessing explicitly:

- `recovered` (**default**): min-max scaling followed by the recovered signed-log mapping;
- `minmax`: linear min-max scaling only;
- `none`: raw numerical values, mainly for sensitivity checks.

This avoids presenting an implementation-level choice that is not fully described in the article as if it were uniquely determined by the paper.

## Repository structure

```text
.
├── R/
│   ├── cpt_core.R          # Data validation, transforms, centers, metrics
│   ├── clustering.R        # Gaussian kernel k-means and k search
│   ├── kernel_xmeans.R     # Clean-room kernel X-means/BIC implementation
│   ├── ann_core.R          # Refactored ANN preprocessing/tuning/evaluation
│   └── cli.R               # Command-line helpers
├── run_full_clustering.R   # Full-dataset k=7..10 analysis
├── run_specific_clustering.R # Specific-dataset kernel X-means analysis
├── run_ann_models.R        # ANN reproduction of derived cluster labels
├── data/
│   └── README.md           # Expected local files, row counts, hashes, rights note
├── legacy/2018/
│   ├── README.md
│   └── CPT_kernel_clustering_recovered_author_source.tar.xz
├── tests/test_core.R
├── CITATION.cff
└── .github/workflows/tests.yml
```

## Data

The paper's Full dataset combines data from several external providers. The recovered files have no redistribution license, so they are deliberately excluded from this public repository.

To run the complete analyses, place authorized local copies of these files under `data/`:

```text
data/completa.csv   85,539 rows
data/metro.csv      41,381 rows
data/cunha.csv       1,199 rows
data/erosao.csv       2,847 rows
```

They sum to the **130,966 observations** reported for the Full dataset. The 2,847-row `erosao.csv` corresponds to the Specific study.

Exact SHA-256 hashes of the recovered copies are listed in [`data/README.md`](data/README.md).

## Requirements

The clustering code requires R and `kernlab`:

```r
install.packages("kernlab")
```

The ANN workflow additionally requires:

```r
install.packages(c("RSNNS", "kknn", "caret"))
```

The historical code was developed with an older R environment, so modern package versions may produce numerical differences.

## Run the Full clustering study

From the repository root:

```bash
Rscript run_full_clustering.R --data-dir data
```

The default search evaluates `k = 7, 8, 9, 10`, uses five deterministic restarts per `k`, and selects the model with the lowest summed within-cluster objective.

Useful options:

```text
--data-dir PATH             directory containing the four authorized CSV files
--k-values 7,8,9,10        candidate cluster counts
--restarts N                random initializations per k (default: 5)
--seed N                    deterministic seed (default: 2020)
--preprocessing MODE        recovered, minmax, or none
--max-rows N                sample N rows for a smoke/performance test only
--output-dir PATH           output directory (default: results)
```

Example short run:

```bash
Rscript run_full_clustering.R \
  --data-dir data \
  --k-values 7,8 \
  --restarts 1 \
  --max-rows 1000
```

`--max-rows` is only a computational smoke-test option and must **not** be used when interpreting results as a rerun of the complete paper dataset.

Outputs include the k-search table, cluster assignments, cluster centers in original physical units, and a compact RDS result object.

## Run the Specific kernel X-means study

```bash
Rscript run_specific_clustering.R --data data/erosao.csv
```

Useful options:

```text
--data PATH                 Specific-dataset CSV
--initial-k N               starting cluster count (default: 2)
--max-k N                   maximum allowed cluster count (default: 10)
--split-restarts N          kernel-k-means restarts for each proposed split
--seed N                    deterministic seed (default: 2020)
--preprocessing MODE        recovered, minmax, or none
--output-dir PATH           output directory (default: results)
```

The maintained implementation uses Gaussian kernel k-means plus an Ishioka-style BIC split test reconstructed independently from the documented algorithm. It does **not** redistribute the third-party X-means source found in the historical archive.

## Run the ANN evaluation

After generating clustering labels:

```bash
Rscript run_ann_models.R \
  --study full \
  --data-dir data \
  --clusters results/full_kernel_kmeans.rds
```

or:

```bash
Rscript run_ann_models.R \
  --study specific \
  --data data/erosao.csv \
  --clusters results/specific_kernel_xmeans.rds
```

The cleaned ANN workflow retains the major design choices recovered from `neuralnet.R`:

- 10-fold train/validation/test evaluation;
- training-based min-max plus signed-log preprocessing;
- class-wise IQR candidate screening;
- 1-NN editing of flagged training observations;
- the historical balancing concept: downsampling large classes and creating minority examples from the feature-wise mean of `d + 1` same-class observations;
- logistic RSNNS multilayer perceptrons;
- validation-based iteration and one-/two-hidden-layer selection;
- hidden-layer size limited to at most twice the number of classes;
- performance measured as mean class recall.

The cleanup makes the balancing RNG deterministic and removes the original system-time seed resets. The 1-NN editing step is also implemented as a stable two-pass operation rather than mutating row indices while filtering.

These are intentional reproducibility/maintainability improvements. New ANN results should therefore be treated as **method-preserving reruns**, not assumed to reproduce the published percentages bit-for-bit.

## Reproducibility limitations

Several factors prevent a defensible claim of exact numerical reproduction from the recovered material alone:

1. the recovered source predates the final article;
2. clustering initialization is stochastic and every historical seed is not documented;
3. the original ANN balancing repeatedly reseeds from system time;
4. the recovered `clustering.R` is an interactive development script rather than a complete linear pipeline;
5. the exact third-party X-means source cannot be republished without clear licensing terms;
6. the complete underlying datasets are not redistributed here.

Accordingly, this repository emphasizes **auditability, paper-oriented reruns, and transparent provenance** rather than claiming exact recreation of the published tables.

## Tests and CI

GitHub Actions runs syntax checks, deterministic preprocessing/metric tests, synthetic kernel-k-means and kernel-X-means smoke tests, and a checksum test for the preserved author-source archive. The paper datasets are not needed for CI.

Run locally with:

```bash
Rscript tests/test_core.R
```

## Citation

Please cite the research article when referring to the scientific results:

```bibtex
@article{Carvalho2020KernelClustering,
  author  = {Carvalho, Lucas Orbolato and Ribeiro, Dimas Betioli},
  title   = {Application of kernel k-means and kernel x-means clustering to obtain soil classes from cone penetration test data},
  journal = {Soils and Rocks},
  volume  = {43},
  number  = {4},
  pages   = {607--618},
  year    = {2020},
  doi     = {10.28927/SR.434607}
}
```

GitHub-compatible citation metadata is also provided in [`CITATION.cff`](CITATION.cff).

## Licensing and third-party material

No software license is asserted for this repository at this stage. The recovered project mixes author code, externally provided datasets, and a modified third-party X-means implementation whose redistribution license is not clear from the recovered file. This cleanup deliberately avoids making broader rights claims than the available provenance supports.
