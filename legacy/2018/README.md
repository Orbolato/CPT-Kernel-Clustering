# Recovered 2018 development source

The author archive supplied in October 2026 was `Não supervisionado.zip` (SHA-256 `f171bb9beb7538d705959f1bb676854405f9a0b08962d629f0a7855e38a75137`). Most analysis files inside it are dated August-October 2018; `neuralnet_accuracy.R` was last modified in June 2020.

The archive is strong provenance for the code lineage behind the 2020 paper, but it is an **interactive development snapshot**, not a self-contained final-paper software release. Examples include absolute Windows paths, references to missing `conf.csv`/`conf_2.csv`, dependence on objects created in a prior interactive session, and a commented kernel-k-means fit followed by downstream references to `kkres`.

## Preserved author-origin source

`CPT_kernel_clustering_recovered_author_source.tar.xz` stores byte-for-byte copies of the author-origin R files recovered from the ZIP:

| File | SHA-256 |
| --- | --- |
| `clustering.R` | `b6d2c85630fe29ed7fcb94979dd0710285b635c51f392d99af1a5822cc75b67c` |
| `analise_artigo.R` | `25ffc1ab21821d3c4a8c363853558ec0f2d2ed7f6cbeeed5838eefd6f1037a8e` |
| `neuralnet.R` | `24219922ab48f8a79c80c60930db1b347713687ad6cbe6b57dcdedfed1f6f833` |
| `neuralnet_accuracy.R` | `3dcf1d2079362877e93e417552374b71cfa2760cca6b43336fe724dd77549eaf` |
| `wmatrix.R` | `861009c25e6bdb0a3210f9af530717aa3128647bfd58526f1f0588adfd03e587` |

Archive SHA-256:

```text
b96d2c3e9f9169ee1b4c5daede0a2a25daaff55035e8b790de7f47c04fc6aea1  CPT_kernel_clustering_recovered_author_source.tar.xz
```

These files are preserved for audit. The maintained top-level code is separately refactored and documented in US English.

## Third-party X-means source

The recovered ZIP also contains `xmeans.R` (SHA-256 `c4ae08567e488431ac3ccd3e1be3423c31a6d744c78a118ce0648c721f90b11c`). Its header identifies it as Tsunenori Ishioka's X-means implementation and cites Ishioka (2000, 2005). The local file was modified to add a kernel-k-means branch using `kernlab::kkmeans`.

No explicit redistribution license was identified in the recovered file. Therefore, **the third-party source itself is intentionally not republished**. `R/kernel_xmeans.R` is a clean-room implementation of the split/BIC procedure used by this project and does not copy that file's source text.

## Data excluded from the provenance archive

The four recovered CSV datasets and `data_folds.RData` are not included because the datasets were assembled from multiple external providers and redistribution rights are not established. Their hashes are documented in `data/README.md`.

`.Rhistory` is also excluded because it is an interactive session artifact rather than scientific source code.

## Reproducibility implications

The recovered scripts use random initialization and, in the ANN balancing step, repeatedly seed from system time. The article also does not report every implementation-level random choice. Consequently, cleaned runs from this repository should be described as **paper-oriented, method-preserving reruns**, not guaranteed bit-for-bit reproductions of the published tables.
