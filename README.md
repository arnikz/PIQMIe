[PIQMIe](http://piqmie.biotools.nl)
=======
[![DOI](https://zenodo.org/badge/42406525.svg)](https://zenodo.org/badge/latestdoi/42406525)

Description
-----------
*PIQMIe* is a web-based tool that aids in reliable and scalable data management, analysis and visualization of semi-quantitative mass spectrometry (MS)-based proteomics experiments ([Kuzniar and Kanaar, 2014](http://www.ncbi.nlm.nih.gov/pubmed/24861615)). *PIQMIe* readily integrates peptide and (non-redundant) protein identifications and quantitations, as obtained from MS data processed by the [MaxQuant/Andromeda](http://maxquant.org) software ([Cox *et al.*, 2008](http://www.ncbi.nlm.nih.gov/pubmed/19029910), [2011](http://www.ncbi.nlm.nih.gov/pubmed/21254760)), with additional biological information from the [UniProtKB](http://www.uniprot.org/) database, and makes the inter-linked data available in the form of a light-weight relational database ([SQLite](http://sqlite.org/)). Using the web interface, users are presented with a concise summary of their proteomics experiments in numerical and graphical forms, as well as with a searchable protein grid and interactive visualization tools to aid in the rapid assessment of the experiments and in the identification of proteins of interest. The web server not only provides data access through a web interface but also supports programmatic access through RESTful API.

A running instance of this proteomics service can be found [here](http://piqmie.biotools.nl).

Dependencies
------------
Python modules:	
+ cherrypy (>=3.2.2)
+ genshi (>=0.7)
+ sqlite3 (>=2.6.0)
+ cairosvg (>=1.0.6)
+ magic (>=0.4.3)

Javascript libraries:
+ jQuery (>=1.11.0)
+ jqGrid (>=4.6.0)
+ D3.js (>=3.3.6)

Installation
------------

Download the source files, set-up user data directory and config the web app.
```
git clone https://github.com/arnikz/PIQMIe.git
```

```
pip install -r requirements.txt
```

```
mkdir <DATA_DIR>                          # create dir for user data
cd PIQMIe/sampledata
tar xvf sampledata.tar.bz2                # extract input files from the archive
x evidence.txt        # MaxQuant peptide list
x proteinGroups.txt   # MaxQuant protein list
x HUMAN.fasta         # protein sequence library (human proteome)
```

```
cd PIQMIe/conf
vim dev.conf # or prod.conf

tools.staticdir.root = "<APP_BASE_DIR>"
tools.sessions.storage_path = "<DATA_DIR>"
```

Start up the web server.

```
cd <APP_BASE_DIR>
```

*for development*

```
cherryd -i PIQMIe -c PIQMIe/conf/dev.conf
```

*for production*

```
sudo cherryd -i PIQMIe -c PIQMIe/conf/prod.conf
```

Enter `http://localhost:8080/` in your web browser to see the *PIQMIe* front page.

Upload your MS data set (i.e. MaxQuant result files including FASTA sequence library) to the web server and press the *Submit* button to process the files. Alternatively, you could use the sample data set (*sampledata.tar.bz2*) on human bone development and mineralization ([Alves *et al.*, 2013](http://www.ncbi.nlm.nih.gov/pubmed/23781072)). After processing the input files, a new sub-directory (*jobID*) will be created in the *DATA_DIR*.

```
cd <DATA_DIR>/<jobID>
ls
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

```
cd ../
mv <jobID> a000000000000000000000000000000000000001 # set-up a default dir for sample data
```

