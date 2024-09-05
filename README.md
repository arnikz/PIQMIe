# PIQMIe

[![DOI](https://zenodo.org/badge/42406525.svg)](https://zenodo.org/badge/latestdoi/42406525)
[![Published in NAR](https://img.shields.io/badge/published%20in-NAR-blue.svg)](https://doi.org/10.1093/nar/gku478)
[![CI](https://github.com/arnikz/PIQMIe/actions/workflows/ci.yaml/badge.svg?branch=dev)](https://github.com/arnikz/PIQMIe/actions/workflows/ci.yaml)

## Description

_PIQMIe_ is a web-based tool for reliable analysis and visualization of semi-quantitative mass spectrometry (MS)-based proteomics data. _PIQMIe_ readily integrates peptide and (non-redundant) protein identifications and quantitations, as obtained by the [MaxQuant/Andromeda](http://maxquant.org/) software ([Cox _et al._, 2008](https://doi.org/10.1038/nbt.1511), [2011](https://doi.org/10.1021/pr101065j)), with additional biological information from the [UniProtKB](http://www.uniprot.org/) database, and makes the linked data available in the form of a light-weight relational database ([SQLite](http://sqlite.org/)). Using the web interface, users are presented with a concise summary of their proteomics experiments in numerical and graphical forms, as well as with a searchable protein grid and interactive visualization tools to aid in the rapid assessment of the experiments and in the identification of proteins of interest. _PIQMIe_ provides data access via a web interface and programmatic RESTful API.

## Requirements
- Perl5
- Python2
  - cherrypy (>=3.2.2)
  - genshi (>=0.7)
  - sqlite3 (>=2.6.0)
  - cairosvg (1.0.22)
  - magic (>=0.4.3)
- Node package manager (npm)
  - bootrap (4.3.1)
  - jqGrid (5.3.2)
  - d3.js (5.9.7)
  - jquery (3.4.1)
  - jquery-form (4.2.2)
  - jquery-ui (1.12.1)
  - jquery-validation (1.19.1)
  - popper.js (1.15.0)

## Installation

```
git clone https://github.com/arnikz/PIQMIe.git
cd PIQMIe
virtualenv .venv --python=python2
source .venv/bin/activate
pip install -r requirements.txt
npm install
```

Extract sample data on human bone development and mineralization ([Alves _et al._, 2013](https://doi.org/10.1074/mcp.M112.024927)).

```
cd data
tar xvf sampledata.tar.bz2
```

Edit `config.ini` file depending on dev or prod mode.

```
#environment = "production"
server.socket_host = "127.0.0.1" # in prod: 0.0.0.0
server.socket_port = 8080 # in prod: 80
...
tools.staticdir.root = "<APP_BASE_DIR>"
tools.staticdir.dir = "PIQMIe"
tools.sessions.storage_path = "<DATA_DIR>" # default: PIQMIe/data
...
log.error_file = "error.log"    # in prod: /var/log/piqmie/error.log
log.access_file = "access.log"  # in prod: /var/log/piqmie/access.log
```

Start up the web server.

```
cd ../  # <APP_BASE_DIR>
cherryd -i PIQMIe -c PIQMIe/config.ini # in prod: sudo ...
```

### Docker deployment

```
cd PIQMIe
docker build -t piqmie .
docker run -d -p 8080:8080 piqmie
docker exec -it [CONTAINER ID] sh
```

## Usage

To view the sample data on your local PIQMIe instance, follow _Sample Data_ tab and click on [results](http://localhost:8080/results/a000000000000000000000000000000000000001).

Alternatively, upload your own data files, i.e., MaxQuant peptide (`evidence.txt`) and protein (`proteinGroups.txt`) lists including the sequence library in FASTA (`.fa|fasta`), to the web server and click on the _Submit_ button to process the input files. After processing, click on the generated link to view the results. Note: For each session, a new (sub)directory `<DATA_DIR>/<jobID>` including I/O files will be created.

