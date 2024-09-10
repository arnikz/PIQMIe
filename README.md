# PIQMIe

[![DOI](https://zenodo.org/badge/42406525.svg)](https://zenodo.org/badge/latestdoi/42406525)
[![Published in NAR](https://img.shields.io/badge/published%20in-NAR-blue.svg)](https://doi.org/10.1093/nar/gku478)
[![CI](https://github.com/arnikz/PIQMIe/actions/workflows/ci.yaml/badge.svg?branch=dev)](https://github.com/arnikz/PIQMIe/actions/workflows/ci.yaml)

## Description

_PIQMIe_ is a web-based tool for reliable analysis and visualization of semi-quantitative mass spectrometry (MS)-based proteomics data. _PIQMIe_ readily integrates peptide and (non-redundant) protein identifications and quantitations, as obtained by the [MaxQuant/Andromeda](http://maxquant.org/) software ([Cox _et al._, 2008](https://doi.org/10.1038/nbt.1511), [2011](https://doi.org/10.1021/pr101065j)), with additional biological information from the [UniProtKB](http://www.uniprot.org/) database, and makes the linked data available in the form of a light-weight relational database ([SQLite](http://sqlite.org/)). Using the web interface, users are presented with a concise summary of their proteomics experiments in numerical and graphical forms, as well as with a searchable protein grid and interactive visualization tools to aid in the rapid assessment of the experiments and in the identification of proteins of interest. _PIQMIe_ provides data access via a web interface and programmatic RESTful API.

## Prerequisites
- [Docker CE](https://docs.docker.com/install/)

## Software stack
- perl
- python
  - cherrypy
  - genshi
  - cairo
- sqlite
- javascript/css
  - jquery
  - d3.js
  - bootstrap

## Install

**1. Clone this repository.**

```bash
git clone https://github.com/arnikz/PIQMIe.git
```

**2. Build and deploy web app.**

```bash
cd PIQMIe
docker build -t piqmie .
docker run -d -p 8080:8080 piqmie
```

## Usage

To view the [sample data](/data) on your local PIQMIe instance, follow _Sample Data_ tab and click on [results](http://localhost:8080/results/a000000000000000000000000000000000000001).

Alternatively, upload your own data files, i.e., MaxQuant peptide (`evidence.txt`) and protein (`proteinGroups.txt`) lists including the sequence library in FASTA (`.fa|fasta`), to the web server and click on the _Submit_ button to process the input files. After processing, click on the generated link to view the results. Note: For each session, a new (sub)directory `<DATA_DIR>/<jobID>` including I/O files will be created.

