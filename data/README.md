# Data availability and local file layout

The datasets recovered with the historical author archive are **not redistributed in this public repository**. The 2020 paper states that the Full dataset combines CPT soundings obtained from several external sources, including data provided by Peter K. Robertson, Paul W. Mayne, Renato P. da Cunha, Heraldo L. Giacheti, and the São Paulo Metropolitan Trains Company. The recovered files do not contain a redistribution license that would justify republishing the complete data bundle here.

To run the analyses locally, place authorized copies of the following files in this directory:

| File | Rows | SHA-256 of recovered copy | Role |
| --- | ---: | --- | --- |
| `completa.csv` | 85,539 | `7581a952b1effce7500c5fa8cc4c82371f7f9e98178bda582940d0c48711e92e` | 111 soundings represented in the recovered combined source (38 Robertson + 73 Mayne in the paper) |
| `metro.csv` | 41,381 | `97de5b12a07073141d93272791b9925a1060461af83d2d2141a6a137721eefa7` | 62 São Paulo Metropolitan soundings |
| `cunha.csv` | 1,199 | `86d0d410e6648b004b929685ee237a0b5e609b74901d436e166a5cc092c60853` | 1 Cunha sounding |
| `erosao.csv` | 2,847 | `1f486c494075421431b6a1a4a08d3a7e42729330601e4b0999d728053df86803` | Specific dataset: measurements from 5 CPT soundings paired with SPT observations |

The row counts sum to **130,966**, exactly matching the Full dataset reported in the article. `erosao.csv` is the 2,847-row Specific subset used for the specialized kernel X-means study.

The maintained code expects at least these four clustering inputs:

- `Depth_m`: depth, m;
- `qc_MPa`: raw cone resistance, MPa;
- `fs_kPa`: sleeve/lateral friction, kPa;
- `u_kPa`: pore pressure measured behind the cone tip, kPa.

The recovered files also contain the reference classification columns `SBTn`, `MSBTn`, and `Cspt`, which can be used for paper-style comparison tables when the user has legitimate access to them.

`data_folds.RData` was also present in the recovered ZIP but is not required by the cleaned clustering runners and is not redistributed.
