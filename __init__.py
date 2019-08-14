# -*- coding: utf-8 -*

import os
import re
import shutil
import subprocess
import shlex
import magic
import math
import sqlite3
import collections
import cairosvg
import cherrypy as cp
# import webbrowser as wb
from cherrypy.lib.static import serve_file
from genshi.template import TemplateLoader

# set file size limits for upload
MB = 1024 ** 2
MAX_PEPFILE_SIZE = MB * 500
MAX_PROTFILE_SIZE = MB * 50
MAX_FASTA_SIZE = MB * 100
MAX_UPLOAD_SIZE = MAX_PEPFILE_SIZE + MAX_PROTFILE_SIZE + MAX_FASTA_SIZE

# set file paths and suffixes
EXE_PATH = os.path.dirname(os.path.abspath(__file__))
DBSCHEMA_PATH = os.path.join(EXE_PATH, 'dbschema')
PARSER_PATH = os.path.join(EXE_PATH, 'parsers')
DBFILE_SFX = 'sqlite'
DATFILE_SFX = 'dat'
FASTA_SFX = ('fa', 'fasta', 'FASTA')

# URL = 'http://{host}:{port}/'.format(host=cp.server.socket_host,
#                                     port=cp.server.socket_port)
loader = TemplateLoader(os.path.join(os.path.dirname(__file__), 'templates'),
                        auto_reload=True)

__author__ = 'Arnold Kuzniar'
__version__ = '1.0.1'


class Piqmie(object):
    """
    This is the base application.
    """

    sql_fetch_expnames = "SELECT DISTINCT(exp_name) FROM EXPERIMENT"

    sql_fetch_nratios_pval = """
        SELECT
            COUNT(DISTINCT CASE WHEN quant_type LIKE '%NORMALIZED' THEN quant_type END) AS n_ratios,
            CASE
                WHEN COUNT(CASE WHEN quant_type LIKE '%SIGNIFICANCE B' THEN quant_type AND quant_value IS NOT NULL END) > 0 THEN 1 ELSE 0
            END AS has_pvalue
        FROM PGROUP_QUANT
      """

    def check_content_length():
        if cp.request.method == 'POST':
            if int(cp.request.headers['Content-Length']) >= MAX_UPLOAD_SIZE:
                raise cp.HTTPError(400, "Uploaded data exceeded the size limit of %d bytes!" % MAX_UPLOAD_SIZE)
    cp.tools.check_content_length = cp.Tool('on_start_resource', check_content_length)

    def _getSessionDir(self, session_id):
        return os.path.join(cp.session.storage_path, session_id)

    def _getFastaFile(self, session_dir):
        for fname in os.listdir(session_dir):
            if fname.endswith(FASTA_SFX):
                return os.path.join(session_dir, fname)

    def _getDbfile(self, session_id):
        session_dir = self._getSessionDir(session_id)
        try:
            for fname in os.listdir(session_dir):
                if fname.endswith(DBFILE_SFX):
                    return os.path.join(session_dir, fname)
        except Exception as e:
            cp.log(e)
            raise cp.HTTPError(400, "Requested JobID: {0} was not found.".format(session_id))

    def _fetchRatioTypes(self, exp_states):
        ratio_types = []
        if exp_states == 2:    # for duplex SILAC
            ratio_types.append('H/L')
            ratio_types.append('L/H')
        elif exp_states == 3:  # for triplex SILAC
            ratio_types.append('H/L')
            ratio_types.append('L/H')
            ratio_types.append('H/M')
            ratio_types.append('M/H')
            ratio_types.append('M/L')
            ratio_types.append('L/M')
        else:
            # shutil.rmtree(session_dir)
            raise cp.HTTPError(400, "No SILAC protein ratios found!")
        return ratio_types

    @cp.expose
    def index(self):
        """
        Serve HTML home page.
        """
        tmpl = loader.load('home.html')
        return tmpl.generate(max_pepfile_size=(MAX_PEPFILE_SIZE / MB),
                             max_protfile_size=(MAX_PROTFILE_SIZE / MB),
                             max_fasta_size=(MAX_FASTA_SIZE / MB))\
                   .render('html', doctype='html5')

    @cp.expose
    def results(self, session_id):
        """
        Show post-processed MaxQuant data in an HTML page.
        """
        db_file = self._getDbfile(session_id)
        with sqlite3.connect(db_file) as conn:
            cur = conn.cursor()
            # cur.execute(Piqmie.sql_fetch_expnames)
            # exp_names = [str(r[0]) for r in cur.fetchall()]
            cur.execute(Piqmie.sql_fetch_nratios_pval)
            (n_ratios, has_pvalue) = cur.fetchone()
            cur.close()

        if n_ratios == 1:  # duplex SILAC
            exp_states = n_ratios + 1
        else:              # triplex SILAC
            exp_states = n_ratios

        # generate HTML from template
        tmpl = loader.load('results.html')
        return tmpl.generate(session_id=session_id,
                             exp_states=exp_states,
                             db_file=os.path.basename(db_file))\
                   .render('html', doctype='html5')

    @cp.expose
    @cp.tools.check_content_length()
    def upload(self, **kw):
        """
        Upload MaxQuant result files to the server and Edit-Transform-Load (ETL)
        files onto a database.
        """
        dts_name = None
        dts_name_key = 'dts_name'
        pep_file = None
        pep_file_key = 'pep_file'
        prot_file = None
        prot_file_key = 'prot_file'
        fasta_file = None
        fasta_file_key = 'fasta_file'

        # by default, the session ID is passed in a cookie,
        # so cookies must be enabled in the client’s browser
        session_id = cp.session.id
        session_dir = self._getSessionDir(session_id)

        # server-side error handling for user input
        if dts_name_key in kw and kw[dts_name_key]:
            dts_name = kw[dts_name_key].strip().replace(' ', '_')

        if pep_file_key in kw and kw[pep_file_key]:
            pep_file = kw[pep_file_key].filename

        if prot_file_key in kw and kw[prot_file_key]:
            prot_file = kw[prot_file_key].filename

        if fasta_file_key in kw and kw[fasta_file_key]:
            fasta_file = kw[fasta_file_key].filename

        # return error messages for incorrect/incomplete input data
        if not dts_name:
            raise cp.HTTPError(400, "Provide a short description of your experiment.")

        if not pep_file or pep_file != 'evidence.txt':
            raise cp.HTTPError(400, "Provide peptide IDs/quantitations file 'evidence.txt'.")

        if not prot_file or prot_file != 'proteinGroups.txt':
            raise cp.HTTPError(400, "Provide protein IDs/quantitations file 'proteinGroups.txt'.")

        if not fasta_file or not fasta_file.endswith(FASTA_SFX):
            raise cp.HTTPError(400, "Provide FASTA sequence library (.fa|.fasta|.FASTA) used for MaxQuant/Andromeda search.")

        # populate a session directory for storing input/output files
        os.mkdir(session_dir)

        # copy input files to the server
        data_size = 0
        for fobj in [kw[prot_file_key], kw[pep_file_key], kw[fasta_file_key]]:
            fname = fobj.filename
            filepath = os.path.join(session_dir, fname)
            with open(filepath, 'w+') as fh:
                for line in fobj.file:  # read data from input stream
                    line = line.rstrip('\r\n') + '\n'  # change to Unix LF
                    data_size += len(line)
                    # set size limit on uploaded data
                    if data_size > MAX_UPLOAD_SIZE:
                        shutil.rmtree(session_dir)
                        raise cp.HTTPError(400, "Uploaded data exceeded the size limit of {0} bytes!".format(MAX_UPLOAD_SIZE))
                    else:
                        fh.write(line)

            # check the size and type of uploaded file
            file_size = os.path.getsize(filepath)
            if file_size == 0:  # file is empty
                shutil.rmtree(session_dir)
                raise cp.HTTPError(400, "Uploaded '{0}' file is empty!".format(fname))
            elif fname == pep_file and file_size > MAX_PEPFILE_SIZE:
                shutil.rmtree(session_dir)
                raise cp.HTTPError(400, "Uploaded peptide list '{0}' is too large!".format(fname))
            elif fname == prot_file and file_size > MAX_PROTFILE_SIZE:
                shutil.rmtree(session_dir)
                raise cp.HTTPError(400, "Uploaded protein list '{0}' is too large!".format(fname))
            elif fname == fasta_file and file_size > MAX_FASTA_SIZE:
                shutil.rmtree(session_dir)
                raise cp.HTTPError(400, "Uploaded FASTA sequence library '{0}' is too large!".format(fname))
            elif magic.from_file(filepath)[:5] != 'ASCII':
                shutil.rmtree(session_dir)
                raise cp.HTTPError(400, "Uploaded file '{0}' is not text/ASCII!".format(fname))
            else:
                pass

        cp.log("Uploading dataset '{0}' completed for session '{1}'.".format(dts_name, session_id))

        # parse FASTA sequence file
        self._parseFastaFile(session_id)
        cp.log("Parsing FASTA file completed for session '{0}'.".format(session_id))

        # parse MaxQuant files
        self._parseProteinList(session_id)
        cp.log("Parsing protein list completed for session '{0}.".format(session_id))

        self._parsePeptideList(session_id)
        cp.log("Parsing peptide list completed for session '{0}'.".format(session_id))

        # create SQLite database
        self._createSQLiteDb(dts_name, session_id)
        cp.log("Processing/uploading data into database completed for session '{0}'.".format(session_id))

        # expire the current session cookie
        # cp.lib.sessions.expire()
        # return session (job) ID
        return session_id

    def _parsePeptideList(self, session_id):
        """
        Method to parse MaxQuant output file 'evidence.txt'.
        """
        session_dir = self._getSessionDir(session_id)
        cmd = os.path.join(PARSER_PATH, "parse_evidence.pl {0}"
                                        .format(session_dir))
        args = shlex.split(str(cmd))
        proc = subprocess.Popen(
            args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        (stdout, stderr) = proc.communicate()
        if proc.wait() != 0:  # parsing error
            # shutil.rmtree(session_dir)
            raise cp.HTTPError(400, stderr)

    def _parseProteinList(self, session_id):
        """
        Method to parse MaxQuant output file 'proteinGroups.txt'.
        """
        session_dir = self._getSessionDir(session_id)
        cmd = os.path.join(
            PARSER_PATH, "parse_proteinGroups.pl {0}".format(session_dir))
        args = shlex.split(str(cmd))
        proc = subprocess.Popen(
            args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        (stdout, stderr) = proc.communicate()
        if proc.wait() != 0:  # parsing error
            # shutil.rmtree(session_dir)
            raise cp.HTTPError(400, stderr)

    def _parseFastaFile(self, session_id):
        """
        Method to parse FASTA sequence file.
        """
        session_dir = self._getSessionDir(session_id)
        fasta_file = self._getFastaFile(session_dir)
        cmd = os.path.join(PARSER_PATH, "parse_fasta.pl {0}".format(
            os.path.join(session_dir, fasta_file)))
        args = shlex.split(str(cmd))
        proc = subprocess.Popen(
            args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        (stdout, stderr) = proc.communicate()
        if proc.wait() != 0:  # parsing error
            # shutil.rmtree(session_dir)
            raise cp.HTTPError(400, stderr)

    def _createSQLiteDb(self, dts_name, session_id):
        """
        Populate a database from parsed MaxQuant files.
        """
        session_dir = self._getSessionDir(session_id)
        db_file = os.path.join(session_dir, '{0}.{1}'.format(dts_name, DBFILE_SFX))
        sql_schema_file = os.path.join(DBSCHEMA_PATH, 'create_schema.sql')
        sql_index_file = os.path.join(DBSCHEMA_PATH, 'create_indices.sql')
        log_file = os.path.join(session_dir, 'LOG')
        sql_create_tables = None
        sql_create_indices = None
        sql_update_tables = None
        tables = []
        sql_check_integrity_expnames = """
            SELECT exp_name FROM EXPERIMENT
            EXCEPT
            SELECT exp_name FROM PGROUP_QUANT
        """
        sql_check_integrity_mappings = """
            SELECT
                n_prot_acc,
                n_prot_acc_link_pgrp_ids,
                n_prot_acc_unlink_pgrp_ids,
                ROUND(100.0 * n_prot_acc_unlink_pgrp_ids / n_prot_acc_link_pgrp_ids, 2) AS perc_prot_unlink_grps,
                n_prot_acc_link_pep_ids,
                n_prot_acc_unlink_pep_ids,
                ROUND(100.0 * n_prot_acc_unlink_pep_ids / n_prot_acc_link_pep_ids, 2) AS perc_prot_unlink_peps
            FROM V_UNMAPPED_PROTEIN_STAT
        """
        sql_get_tables = "SELECT name FROM sqlite_master WHERE type = 'table'"

        # populate db schema from an SQL script
        if os.path.getsize(sql_schema_file) == 0:
            raise cp.HTTPError(500, "The SQL batch script '{0}' is empty!"
                                    .format(sql_schema_file))

        with open(sql_schema_file) as fin:
            lines = fin.readlines()
            sql_create_tables = ''.join(lines)

        with sqlite3.connect(db_file) as conn:  # connect to db
            cur = conn.cursor()
            cur.executescript(sql_create_tables)  # execute multiple statements
            cur.execute(sql_get_tables)           # fetch table names
            tables = cur.fetchall()               # store table names

            # import data into db tables
            sep = '\\t'  # record separator
            meta_stmt = "PRAGMA synchronous = OFF;\n"
            meta_stmt += "PRAGMA journal_mode = OFF;\n"
            meta_stmt += "PRAGMA cache_size = 10000;\n"
            meta_stmt += ".separator {0}\n".format(sep)
            sql_import_file = os.path.join(session_dir, 'import_data.sql')
            for t in tables:
                tname = t[0]
                meta_stmt += ".import '{0}.{1}' {2}\n".format(
                    os.path.join(session_dir, tname), DATFILE_SFX, tname)
                with open(sql_import_file, 'w') as fout:  # write meta-commands
                    fout.write(meta_stmt)

            cmd = "sqlite3 {0} < {1}".format(db_file, sql_import_file)
            if os.system(cmd) != 0:  # sqlite error
                # shutil.rmtree(session_dir)
                raise cp.HTTPError(500, "Failed to import data into the database!")

            # create table indices: source create index statements from *.sql file
            with open(sql_index_file) as fin:  # read SQL statements into a string
                lines = fin.readlines()
                sql_create_indices = ''.join(lines)
            cur.executescript(sql_create_indices)  # execute multiple statements

            # update tables and check their integrity:
            #   replace '\N' values with NULL => this will raise IntegrityError
            #   on mandatory columns (see parse_*.pl scripts for details)
            sql_update_tables = """
                BEGIN;
                    UPDATE PEPTIDE SET raw_file = NULLIF(raw_file, '{cur}'),
                        seq = NULLIF(seq, '{cur}'),
                        mods = NULLIF(mods, '{cur}'),
                        charge = NULLIF(charge, '{cur}'),
                        mass = NULLIF(mass, '{cur}'),
                        retime = NULLIF(retime, '{cur}'),
                        pep_score = NULLIF(pep_score, '{cur}'),
                        res_fwhm = NULLIF(res_fwhm, '{cur}'),
                        is_decoy = NULLIF(is_decoy, '{cur}'),
                        is_cont = NULLIF(is_cont, '{cur}');

                    UPDATE PEPTIDE_QUANT SET exp_name = REPLACE(exp_name, '{cur}', '{new}'),
                        quant_type = NULLIF(quant_type, '{cur}'),
                        quant_value = NULLIF(quant_value, '{cur}');

                    UPDATE PROTEIN SET id = NULLIF(id, '{cur}'),
                        evidence = NULLIF(evidence, '{cur}'),
                        gene = NULLIF(gene, '{cur}'),
                        db = NULLIF(db, '{cur}'),
                        des = NULLIF(des, '{cur}'),
                        org = NULLIF(org, '{cur}'),
                        seq = NULLIF(seq, '{cur}');

                    UPDATE PGROUP SET pep_score = NULLIF(pep_score, '{cur}'),
                        id_by_site = NULLIF(id_by_site, '{cur}'),
                        is_decoy = NULLIF(is_decoy, '{cur}'),
                        is_cont = NULLIF(is_cont, '{cur}');

                    UPDATE PGROUP_QUANT SET exp_name = REPLACE(exp_name, '{cur}', '{new}'),
                        quant_value = NULLIF(quant_value, '{cur}'),
                        quant_value = NULLIF(quant_value, '{cur}');

                    UPDATE EXPERIMENT SET exp_name = REPLACE(exp_name, '{cur}', '{new}');
                END;
            """.format(cur='\N', new=dts_name)

            try:
                cur.executescript(sql_update_tables)
            except sqlite3.IntegrityError as e:
                cp.log(e)
                raise cp.HTTPError(400, "Data integrity error: values missing in table.column(s).")

            # check the integrity of peptide/protein mappings
            cur.execute(sql_check_integrity_mappings)
            row = cur.fetchone()
            cutoff_unmapped = 10  # max. percent of unmapped proteins
            if (row[3] > cutoff_unmapped):
                raise cp.HTTPError(400, "Data integrity error: %d out of %d protein accession (%.2d%%) in the protein list ('proteinGroups.txt') are not found in the FASTA sequence library used (%d accessions). Make sure to use the same FASTA sequence library from UniProtKB as used for the MaxQuant/Andromeda search!" % (row[2], row[1], row[3], row[0]))
            elif (row[6] > cutoff_unmapped):
                raise cp.HTTPError(400, "Data integrity error: %d out of %d protein accession (%.2d%%) in the peptide list ('evidence.txt') are not found in the FASTA sequence library used (%d accessions). Make sure to use the same FASTA sequence library from UniProtKB as used for the MaxQuant/Andromeda search!" % (row[5], row[4], row[6], row[0]))
            else:
                pass

            # check the integrity of experiment names
            cur.execute(sql_check_integrity_expnames)
            row = cur.fetchone()
            if row is not None:
                raise cp.HTTPError(400, "Data integrity error: experiment name(s) do not match between the peptide and protein lists. Upload MaxQuant files obtained from the same run!")

            # add a view with all experiments x ratio type combinations
            cur.execute(Piqmie.sql_fetch_expnames)
            exp_names = [str(r[0]) for r in cur.fetchall()]

            cur.execute(Piqmie.sql_fetch_nratios_pval)
            (n_ratios, has_pvalue) = cur.fetchone()
            if n_ratios == 1:  # duplex SILAC
                exp_states = n_ratios + 1
            else:              # triplex SILAC
                exp_states = n_ratios

            # set ratio types
            ratio_types = self._fetchRatioTypes(exp_states)
            sql_create_pgrp_view = "CREATE VIEW VVV_PGROUP_QUANT AS\n"
            sql_create_pgrp_view += "-- view to show protein (group) quantitations for all experiments and ratios.\n"
            sql_create_pgrp_view += "SELECT\n\tgrp_id,\n"
            comma = ','
            n = len(exp_names) * len(ratio_types)
            i = 0

            for e in exp_names:
                for r in ratio_types:
                    i += 1
                    if i == n:
                        comma = ''
                    r = r.replace("/", "")
                    c = 'norm_ratio_%s' % r
                    sql_create_pgrp_view += "\tCAST(GROUP_CONCAT(CASE WHEN exp_name = '{exp_name}' THEN {col} ELSE NULL END) AS NUMERIC) AS '{exp_name}_{col}',\n".format(exp_name=e, col=c)
                    sql_create_pgrp_view += "\tCAST(GROUP_CONCAT(CASE WHEN exp_name = '{exp_name}' THEN sig_ratio_{ratio} ELSE NULL END) AS NUMERIC) AS '{exp_name}_sig_ratio_{ratio}',\n".format(exp_name=e, ratio=r)
                    sql_create_pgrp_view += "\tCAST(GROUP_CONCAT(CASE WHEN exp_name = '{exp_name}' THEN sd_ratio_{ratio} ELSE NULL END) AS NUMERIC) AS '{exp_name}_sd_ratio_{ratio}',\n".format(exp_name=e, ratio=r)
                    sql_create_pgrp_view += "\tCAST(GROUP_CONCAT(CASE WHEN exp_name = '{exp_name}' THEN n_pep_qts_{ratio} ELSE NULL END) AS NUMERIC) AS '{exp_name}_n_pep_qts_{ratio}'{comma}\n".format(exp_name=e, ratio=r, comma=comma)
            sql_create_pgrp_view += "FROM VV_PGROUP_QUANT GROUP BY grp_id"
            cur.execute(sql_create_pgrp_view)
            cur.close()

        # write LOG file upon successful job completion
        with open(log_file, 'w') as fout:
            fout.write(db_file)

    @cp.expose
    def download(self, session_id, filename):
        """
        Serve static files for download.
        """
        filepath = os.path.join(cp.session.storage_path, session_id, filename)
        return serve_file(filepath, 'application/x-download', 'attachment')

    @cp.expose
    def saveImage(self, session_id, query_str, output_format, data):
        """
        Serve image files for download.
        """
        filename = ".".join((query_str, output_format))
        filepath = os.path.join(cp.session.storage_path, session_id, filename)

        if os.path.exists(filepath):
            os.remove(filepath)
        data = data.encode('utf8', 'replace')

        with open(filepath, 'w') as fout:  # write image file (.svg|.png|.pdf)
            if output_format == 'svg':
                cairosvg.svg2svg(bytestring=data, write_to=fout)
            elif output_format == 'png':
                cairosvg.svg2png(bytestring=data, write_to=fout)
            elif output_format == 'pdf':
                cairosvg.svg2pdf(bytestring=data, write_to=fout)
            else:
                pass
        return serve_file(filepath, 'application/x-download', 'attachment')

    @cp.expose
    def pepmap(self, session_id, grp_id, exp=None):
        """
        Show the peptide coverage map in an HTML page.
        """
        db_file = self._getDbfile(session_id)
        with sqlite3.connect(db_file) as conn:
            cur = conn.cursor()
            cur.execute(Piqmie.sql_fetch_expnames)
            exp_names = [str(r[0]) for r in cur.fetchall()]
            if exp is None:
                exp = ",".join(exp_names)  # experiment names
            # generate HTML from template
            tmpl = loader.load('pepmap.html')
            stream = tmpl.generate(
                session_id=session_id,  # session ID
                sel_grp_id=grp_id,      # selected protein group
                sel_exp_name=exp,       # selected experiment(s)
                exp_names=exp_names     # array of experiment names
            )
            return stream.render('html', doctype='html5')

    @cp.expose
    def scatterplot(self, session_id, exp1=None, exp2=None, ratio1=None, ratio2=None, cfratio=1, cfpvalue=1):
        """
        Show the 2D scatterplot of protein quantitations in an HTML page.
        """
        db_file = self._getDbfile(session_id)
        conn = sqlite3.connect(db_file)
        cur = conn.cursor()
        cur.execute(Piqmie.sql_fetch_expnames)
        exp_names = [str(r[0]) for r in cur.fetchall()]
        cur.execute(Piqmie.sql_fetch_nratios_pval)
        (n_ratios, has_pvalue) = cur.fetchone()

        if n_ratios == 1:  # duplex SILAC
            exp_states = n_ratios + 1
        else:              # triplex SILAC
            exp_states = n_ratios

        if has_pvalue == 0:
            cfpvalue_ctrl = 'disabled'
        else:
            cfpvalue_ctrl = ''  # disable/enable HTML slider

        # set defaults for URL parameters
        if not exp1:
            exp1 = exp_names[0]

        if not exp2:
            exp2 = exp_names[0]

        if not ratio1:
            ratio1 = 'H/L'

        if not ratio2:
            ratio2 = 'H/L'

        ratio_types = self._fetchRatioTypes(exp_states)
        # generate HTML from template
        tmpl = loader.load('scatterplot.html')
        stream = tmpl.generate(
            session_id=session_id,
            cfpvalue_ctrl=cfpvalue_ctrl,  # enable/disable cfpvalue input element
            sel_exp_name_1=exp1,          # selected experiment 1
            sel_exp_name_2=exp2,          # selected experiment 2
            sel_ratio_1=ratio1,           # selected ratio for experiment 1
            sel_ratio_2=ratio2,           # selected ratio for experiment 2
            sel_cfratio=cfratio,          # selected ratio cutoff (applied to both experiments)
            sel_cfpvalue=cfpvalue,        # selected significance cutoff (applied to both experiments)
            exp_names=exp_names,          # set of all experiments
            ratio_types=ratio_types)      # set of all possible ratio types
        return stream.render('html', doctype='html5')

    @cp.expose
    @cp.tools.json_out()
    def rest(self, session_id, query, **kw):
        grp_id = None
        str_exp_names, exp, exp1, exp2 = None, None, None, None
        ratio1, ratio2 = None, None
        cfratio, cfpvalue = None, None

        # select all experiments by default
        db_file = self._getDbfile(session_id)
        with sqlite3.connect(db_file) as conn:
            cur = conn.cursor()
            cur.execute(Piqmie.sql_fetch_expnames)
            exp_names = [str(r[0]) for r in cur.fetchall()]
            cur.close()

        # parse and set URL params
        if 'grp_id' in kw:
            grp_id = kw['grp_id']

        if 'exp1' in kw:
            exp1 = kw['exp1']

        if 'exp2' in kw:
            exp2 = kw['exp2']

        if 'ratio1' in kw:
            ratio1 = kw['ratio1'].replace("/", "")

        if 'ratio2' in kw:
            ratio2 = kw['ratio2'].replace("/", "")

        if 'cfratio' in kw:
            cfratio = float(kw['cfratio'])

        if 'cfpvalue' in kw:
            cfpvalue = float(kw['cfpvalue'])
            if cfpvalue == 1:
                cfpvalue += 0.1  # N.B.: increment needed to select all rows

        if 'exp' in kw:
            exp = kw['exp']

        str_exp_names = "','".join(exp_names) if exp is None else "','".join(exp.split(','))

        #
        # User-defined SQL functions (UDFs) for SQLite
        #

        def pepmatch(pep_seq, prot_seq):
            """
            Find peptime matches ([start]-[end] positions) on the parent protein.
            Multiple matches of the same peptide are separated by ','.
            """
            if not pep_seq or not prot_seq:
                return None
            pat = re.sub('I|L', '[IL]', pep_seq)
            pos = ["-".join((str(m.start() + 1), str(m.end()))) for m in re.finditer(pat, prot_seq)]
            return ",".join([str(p) for p in pos])

        def log(value, base):
            if not value:
                return None
            return math.log(value) / math.log(base)

        def filter(value):
            """
            Return a non-redundant set of protein annotations in the
            'prot_names' column. Remove duplicate, uninformative annotations
            or information about isoform(s) from the set.
            """
            if not value:
                return None
            sep = '","'
            uniq = dict()
            for e in value.split(sep):
                new = re.sub('isoform\s+\S+\s+of\s+|,?\s+isoform.*|\s+\(Fragment\)|uncharacterized\s+protein|unknown\s+protein|"', '', e, flags=re.I)
                if new not in uniq and new:
                    uniq[new] = None
            return '"' + sep.join(uniq.keys()) + '"' if uniq.keys() else None

        # SQL queries used for HTTP requests
        sql_statgrp = "SELECT * FROM V_PGROUP_STAT"
        sql_statpep = "SELECT * FROM V_PEPTIDE_STAT"
        sql_statprot = "SELECT * FROM V_PROTEIN_STAT"
        sql_statregrp = "SELECT * FROM V_REG_PGROUP_STAT"
        sql_grp = """
            SELECT
                grp_id,
                grp_size,
                exp_name,
                prot_accs,
                FILTER(prot_names) AS prot_names,
                gene_names,
                grp_evidence,
                org,
                pep_score,
                norm_ratio_HL,
                norm_ratio_LH,
                norm_ratio_HM,
                norm_ratio_MH,
                norm_ratio_ML,
                norm_ratio_LM,
                n_pep_qts_HL,
                n_pep_qts_HM,
                n_pep_qts_ML,
                sd_ratio_HL,
                sd_ratio_HM,
                sd_ratio_ML,
                sig_ratio_HL,
                sig_ratio_HM,
                sig_ratio_ML
            FROM V_PGROUP_MEMBERS
        """

        sql_pepmap = """
            SELECT
                db,
                prot_acc,
                CASE WHEN MAX(lead_prot) > 0 THEN 1 ELSE 0 END AS is_lead_prot,
                gene,
                des,
                prot_len,
                GROUP_CONCAT(pep_id || ":" || PEPMATCH(pep_seq, prot_seq) || ":" || pep_seq, ";") AS pep_map
            FROM
                (SELECT DISTINCT * FROM V_PEP2GRP A INNER JOIN (SELECT pep_id FROM PEPTIDE_QUANT WHERE exp_name IN ('{0}') AND SUBSTR(quant_type, 1, 1) = 'R' AND quant_value) B USING (pep_id) WHERE grp_id = :1)
            GROUP BY prot_acc ORDER BY db, prot_len DESC
        """.format(str_exp_names)

        sql_cmpquant = """
            SELECT
                grp_id,
                COUNT(acc) AS grp_size,
                GROUP_CONCAT(db || ':' || acc) AS prot_accs,
                FILTER(GROUP_CONCAT(REPLACE(des, '"', ''), '","')) AS prot_names,
                GROUP_CONCAT(DISTINCT gene) AS gene_names,
                CASE
                    WHEN MIN(evidence) = 1 THEN 'protein'
                    WHEN MIN(evidence) = 2 THEN 'transcript'
                    WHEN MIN(evidence) = 3 THEN 'homology'
                    WHEN MIN(evidence) = 4 THEN 'predicted'
                    WHEN MIN(evidence) = 5 THEN 'uncertain'
                    ELSE 'unknown'
                END AS grp_evidence,
                org,
                ratio1,
                ROUND(LOG(ratio1, 2), 2) AS log2_ratio1,
                fc1,
                sd_ratio1,
                n_pep_qts1,
                ratio2,
                ROUND(LOG(ratio2, 2), 2) AS log2_ratio2,
                fc2,
                sd_ratio2,
                n_pep_qts2,
                sig_ratio1,
                sig_ratio2
            FROM (
                SELECT
                    T.grp_id,
                    ratio1,
                    fc1,
                    sd_ratio1,
                    ratio2,
                    fc2,
                    sd_ratio2,
                    n_pep_qts1,
                    n_pep_qts2,
                    sig_ratio1,
                    sig_ratio2,
                    db,
                    acc,
                    IFNULL(evidence, 6) AS evidence,
                    gene,
                    des,
                    org
                FROM (
                    SELECT
                        A.grp_id,
                        CAST(GROUP_CONCAT(CASE WHEN exp_name = :1 THEN norm_ratio_{r1} ELSE NULL END) AS NUMERIC) AS ratio1,
                        CAST(GROUP_CONCAT(CASE WHEN exp_name = :2 THEN norm_ratio_{r2} ELSE NULL END) AS NUMERIC) AS ratio2,
                        CAST(GROUP_CONCAT(CASE WHEN exp_name = :1 THEN FC_{r1} ELSE NULL END) AS NUMERIC) AS fc1,
                        CAST(GROUP_CONCAT(CASE WHEN exp_name = :2 THEN FC_{r2} ELSE NULL END) AS NUMERIC) AS fc2,
                        CAST(GROUP_CONCAT(CASE WHEN exp_name = :1 THEN sd_ratio_{r1} ELSE NULL END) AS NUMERIC) AS sd_ratio1,
                        CAST(GROUP_CONCAT(CASE WHEN exp_name = :2 THEN sd_ratio_{r2} ELSE NULL END) AS NUMERIC) AS sd_ratio2,
                        CAST(GROUP_CONCAT(CASE WHEN exp_name = :1 THEN n_pep_qts_{r1} ELSE NULL END) AS NUMERIC) AS n_pep_qts1,
                        CAST(GROUP_CONCAT(CASE WHEN exp_name = :2 THEN n_pep_qts_{r2} ELSE NULL END) AS NUMERIC) AS n_pep_qts2,
                        CAST(GROUP_CONCAT(CASE WHEN exp_name = :1 THEN sig_ratio_{r1} ELSE NULL END) AS NUMERIC) AS sig_ratio1,
                        CAST(GROUP_CONCAT(CASE WHEN exp_name = :2 THEN sig_ratio_{r2} ELSE NULL END) AS NUMERIC) AS sig_ratio2
                    FROM
                        V_PGROUP A, VV_PGROUP_QUANT B
                    WHERE
                        A.grp_id = B.grp_id
                    GROUP BY A.grp_id) T, PROT2GRP C, V_PROTEIN D
                WHERE
                    T.grp_id = C.grp_id
                    AND C.prot_acc = D.acc
                    AND fc1 >= :3 AND fc2 >= :3
                    AND IFNULL(sig_ratio1, 0) < :4 AND IFNULL(sig_ratio2, 0) < :4 -- N.B.: returns true for sig_ratio = 1 and cfpvalue = 1 + 0.1
                    ORDER BY T.grp_id, db) M
            GROUP BY grp_id
        """.format(r1=ratio1, r2=ratio2)

        # map HTTP requests to SQL queries
        q2sql = dict(statgrp=sql_statgrp,
                     statregrp=sql_statregrp,
                     statpep=sql_statpep,
                     statprot=sql_statprot,
                     grp=sql_grp,
                     pepmap=sql_pepmap,
                     cmpquant=sql_cmpquant)

        if query not in q2sql:
            raise cp.HTTPError(400, 'Unsupported HTTP request!')

        # connect to db
        with sqlite3.connect(db_file) as conn:
            # register UDFs in db
            conn.create_function('pepmatch', 2, pepmatch)
            conn.create_function('log', 2, log)
            conn.create_function('filter', 1, filter)
            conn.row_factory = sqlite3.Row  # access columns by name
            cur = conn.cursor()

            if query == 'pepmap':
                cur.execute(q2sql[query], (grp_id,))
            elif query == 'cmpquant':
                cur.execute(q2sql[query], (exp1, exp2, cfratio, cfpvalue))
            else:
                cur.execute(q2sql[query])
            rows = cur.fetchall()
            cur.close()
            return [collections.OrderedDict(xi) for xi in rows]


if __name__ == '__main__':
    cp.quickstart(Piqmie())
else:
    # open the default web browser
    # wb.open_new_tab(URL)
    # mount the root application
    cp.tree.mount(Piqmie(), '/')
