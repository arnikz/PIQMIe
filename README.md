# [PIQMIe](http://piqmie.biotools.nl)

[![DOI](https://zenodo.org/badge/42406525.svg)](https://zenodo.org/badge/latestdoi/42406525)

## Description

_PIQMIe_ is a web-based tool for reliable analysis and visualization of semi-quantitative mass spectrometry (MS)-based proteomics data ([Kuzniar and Kanaar, 2014](https://doi.org/10.1093/nar/gku478)). _PIQMIe_ readily integrates peptide and (non-redundant) protein identifications and quantitations, as obtained by the [MaxQuant/Andromeda](http://maxquant.org/) software ([Cox _et al._, 2008](https://doi.org/10.1038/nbt.1511), [2011](https://doi.org/10.1021/pr101065j)), with additional biological information from the [UniProtKB](http://www.uniprot.org/) database, and makes the linked data available in the form of a light-weight relational database ([SQLite](http://sqlite.org/)). Using the web interface, users are presented with a concise summary of their proteomics experiments in numerical and graphical forms, as well as with a searchable protein grid and interactive visualization tools to aid in the rapid assessment of the experiments and in the identification of proteins of interest. _PIQMIe_ provides data access via a web interface and programmatic RESTful API.

## Requirements

Python modules:

- cherrypy (>=3.2.2)
- genshi (>=0.7)
- sqlite3 (>=2.6.0)
- cairosvg (>=1.0.6)
- magic (>=0.4.3)

Javascript libraries:

- jQuery (>=1.11.0)
- jqGrid (>=4.6.0)
- D3.js (>=3.3.6)

## Installation

```
git clone https://github.com/arnikz/PIQMIe.git
cd PIQMIe
virtualenv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Extract sample data files on human bone development and mineralization ([Alves _et al._, 2013](https://doi.org/10.1074/mcp.M112.024927)).

```
cd PIQMIe/data
tar xvf sampledata.tar.bz2
```

MaxQuant peptide list: `evidence.txt`

MaxQuant protein list: `proteinGroups.txt`

Protein sequences from UniProtKB: `HUMAN.fasta`

Edit `conf/config.ini` file depending on dev or prod mode.

```
#environment = "production"
server.socket_host = "127.0.0.1" # in prod: 0.0.0.0
server.socket_port = 8080 # in prod: 80
...
tools.staticdir.root = "<APP_BASE_DIR>"
tools.staticdir.dir = "PIQMIe"
tools.sessions.storage_path = "<DATA_DIR>"
...
log.error_file = "error.log"    # in prod: /var/log/piqmie/error.log
log.access_file = "access.log"  # in prod: /var/log/piqmie/access.log
```

Start up the web server.

```
cd <APP_BASE_DIR>
cherryd -i PIQMIe -c PIQMIe/conf/config.ini # sudo in prod
```

## Usage

Visit PIQMIe production instance at <http://piqmie.biotools.nl> (or <http://localhost:8080/> for local development).

Upload MaxQuant peptide/protein lists (`.txt`) including the corresponding sequence library in FASTA (`.fa|fasta`) to the web server, and press the _Submit_ button to process the input files. After processing, a new sub-directory `<DATA_DIR>/<jobID>` is created with input/output files:

```
ls <DATA_DIR>/<jobID>
EXPERIMENT.dat
HUMAN.fasta
PEP2PROT.dat
PEPTIDE.dat
PEPTIDE_QUANT.dat
PGROUP.dat
PGROUP_QUANT.dat
PROT2GRP.dat
PROTEIN.dat
evidence.txt
proteinGroups.txt
sampledata.sqlite
```

## How to cite

Kuzniar, A. and Kanaar, R. (2014) PIQMIe: a web server for semi-quantitative proteomics data management and analysis, _Nucleic Acids Research_, 42, W100–W106\. doi:[10.1093/nar/gku478](https://doi.org/10.1093/nar/gku478)

Kuzniar, A. PIQMIe version 1.0\. doi:[10.5281/zenodo.34090](https://doi.org/10.5281/zenodo.34090)
