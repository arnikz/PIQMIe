[PIQMIe](http://piqmie.semiqprot-emc.cloudlet.sara.nl/)
=======

Description
-----------
*PIQMIe* is a web-based tool that aids in reliable and scalable data management, analysis and visualization of semi-quantitative mass spectrometry (MS)-based proteomics experiments ([Kuzniar and Kanaar, 2014](http://www.ncbi.nlm.nih.gov/pubmed/24861615)). PIQMIe readily integrates peptide and (non-redundant) protein identifications and quantitations, as obtained from MS data processed by the [MaxQuant/Andromeda](http://maxquant.org) software ([Cox *et al.*, 2008](http://www.ncbi.nlm.nih.gov/pubmed/19029910), [2011](http://www.ncbi.nlm.nih.gov/pubmed/21254760)), with additional biological information from the [UniProtKB](http://www.uniprot.org/) database, and makes the inter-linked data available in the form of a light-weight relational database ([SQLite](http://sqlite.org/)). Using the web interface, users are presented with a concise summary of their proteomics experiments in numerical and graphical forms, as well as with a searchable protein grid and interactive visualization tools to aid in the rapid assessment of the experiments and in the identification of proteins of interest. The web server not only provides data access through a web interface but also supports programmatic access through RESTful API.

Dependencies
------------
Python modules:	
+ cherrypy (3.2.2)
+ genshi (0.7)
+ sqlite3 (2.6.0)
+ cairosvg (1.0.6)

Javascript libraries:
+ jQuery (1.11.0)
+ jqGrid (4.6.0)
+ D3.js (3.3.6)

Installation
------------
Download the source files and edit the config file.

```
cd PIQMIe/conf
vim dev.conf # or prod.conf
```

```
tools.staticdir.root = "path_to_your_PIQMIe_base_dir"
tools.sessions.storage_path = "path_to_your_data_dir"
```

Start up the web server.

```
cd ../../
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

Upload your MS data set i.e. MaxQuant result files including FASTA sequence library to the web server and press the *Submit* button to process it. Alternatively, you could use the sample data set on human bone development and mineralization ([Alves *et al.*, 2013](http://www.ncbi.nlm.nih.gov/pubmed/23781072)).

```
cd PIQMIe/sampledata
tar xvzf sample.tar.gz
```
