--
-- Written by: Arnold Kuzniar
--
-- Last update: 20/12/2017
--

--
-- Table PEPTIDE.
--

DROP TABLE IF EXISTS PEPTIDE;
CREATE TABLE PEPTIDE
-- stores partial data from the uploaded 'evidence.txt' file
(
    pep_id    NUMERIC NOT NULL, -- internal peptide ID
    raw_file  TEXT NOT NULL,    -- name of the RAW file from which the spectral data was derived
    seq       TEXT NOT NULL,    -- peptide sequence
    mods      TEXT,             -- peptide modifications in the form of mod(AA): pos1,pos2...
    charge    NUMERIC NOT NULL, -- charge of the peptide fragment
    mass      NUMERIC NOT NULL, -- predicted monoisotopic mass of the identified peptide sequence (Da)
    retime    NUMERIC NOT NULL, -- calibrated retention time (min)
    pep_score NUMERIC NOT NULL, -- Posterior Error Probability (PEP) score of the peptide identification
    res_fwhm  NUMERIC,          -- resolution of the precursor ion measured in Full Width at Half Maximum (FWHM).
    is_decoy  NUMERIC NOT NULL, -- peptide is (not) a false positive hit (decoy)
    is_cont   NUMERIC NOT NULL, -- peptide is (not) a contaminant
    PRIMARY KEY(pep_id),
    FOREIGN KEY(raw_file) REFERENCES EXPERIMENT(raw_file)
);


--
-- Table PROTEIN.
--

DROP TABLE IF EXISTS PROTEIN;
CREATE TABLE PROTEIN
-- stores data from the uploaded UniProtKB FASTA file
(
    acc       TEXT NOT NULL,  -- protein accession
    id        TEXT NOT NULL,  -- protein identifiers
    evidence  NUMERIC,        -- evidence number or protein existence
    gene      TEXT,           -- official gene symbol of the protein-coding gene
    db        TEXT NOT NULL,  -- source database: 'sp' = UniProtKB/Swiss-Prot or 'tr' = UniProt/TrEMBL
    des       TEXT NOT NULL,  -- official protein name (description)
    org       TEXT NOT NULL,  -- source organism (species name)
    seq       TEXT NOT NULL,  -- protein sequence
    PRIMARY KEY(acc)
);


--
-- Table PGROUP.
--

DROP TABLE IF EXISTS PGROUP;
CREATE TABLE PGROUP
-- stores partial data from the uploaded 'proteinGroups.txt' file
(
    grp_id      NUMERIC NOT NULL, -- internal (protein) group ID
    pep_score   NUMERIC NOT NULL, -- PEP score of the group identification
    id_by_site  NUMERIC NOT NULL, -- group identified only by modification site
    is_decoy    NUMERIC NOT NULL, -- group is (not) a false positive hit (decoy)
    is_cont     NUMERIC NOT NULL, -- group is (not) a contaminant
    PRIMARY KEY(grp_id)
);


--
-- Table PEP2PROT.
--

DROP TABLE IF EXISTS PEP2PROT;
CREATE TABLE PEP2PROT
-- stores peptide-is_part_of-protein relations based on the 'evidence.txt' file
-- excludes protein accessions with CON__ and REV__ prefix (contaminants and decoys)
(
    pep_id    NUMERIC NOT NULL, -- peptide ID
    prot_acc  TEXT NOT NULL,    -- protein accession
    lead_prot NUMERIC NOT NULL, -- 0 = not a leading protein, 1 = leading protein, 2 = leading razor (best scoring) protein
    FOREIGN KEY(pep_id) REFERENCES PEPTIDE(pep_id),
    FOREIGN KEY(prot_acc) REFERENCES PROTEIN(acc)
);


--
-- Table PROT2GRP.
--

DROP TABLE IF EXISTS PROT2GRP;
CREATE TABLE PROT2GRP
-- stores protein-is_part_of-group relations based on the 'proteinGroups.txt' file
-- excludes protein accessions with CON__ and REV__ prefix (contaminants and decoys)
(
    grp_id    NUMERIC NOT NULL, -- protein group ID
    prot_acc  TEXT NOT NULL,    -- protein accession
    FOREIGN KEY(grp_id) REFERENCES PGROUP(grp_id),
    FOREIGN KEY(prot_acc) REFERENCES PROTEIN(acc)
);


--
-- Table EXPERIMENT.
--

DROP TABLE IF EXISTS EXPERIMENT;
CREATE TABLE EXPERIMENT
-- stores the correspondance between experiment names and RAW files
(
    raw_file  TEXT NOT NULL, -- prefix of the *.RAW file
    exp_name  TEXT NOT NULL, -- experiment name
    PRIMARY KEY(raw_file)
);

--
-- Table PEPTIDE_QUANT.
--

DROP TABLE IF EXISTS PEPTIDE_QUANT;
CREATE TABLE PEPTIDE_QUANT
-- stores peptide-level quantitative data from the 'evidence.txt' file
(
    pep_id      NUMERIC NOT NULL,   -- peptide ID
    exp_name    TEXT NOT NULL,      -- experiment name
    quant_type  TEXT NOT NULL,      -- type of quantitative measurement e.g., RATIO H/L, RATIO H/L NORMALIZED, INTENSITY H, INTENSITY L
    quant_value TEXT,               -- value of the quantity (to handle '\N' or NULL the field must be of TEXT type)
    FOREIGN KEY(pep_id) REFERENCES PEPTIDE(pep_id)
);


--
-- Table PGROUP_QUANT.
--

DROP TABLE IF EXISTS PGROUP_QUANT;
CREATE TABLE PGROUP_QUANT
-- stores protein (group)-level quantitative data from the 'proteinGroups.txt' file
(
    grp_id      NUMERIC NOT NULL, -- group ID
    exp_name    TEXT NOT NULL,    -- experiment name
    quant_type  TEXT NOT NULL,    -- type of quantitative measurement: RATIO H/L, RATIO H/L NORMALIZED, RATIO H/L NORMALIZED SIGNIFICANCE B, RATIO H/L VARIABILITY, RATIO H/L COUNT, INTENSITY H, INTENSITY L
    quant_value TEXT,             -- value of the quantity (to handle '\N' or NULL the field must be TEXT)
    FOREIGN KEY(grp_id) REFERENCES PGROUP(grp_id)
);


--
-- View V_PEPTIDE.
--

DROP VIEW IF EXISTS V_PEPTIDE;
CREATE VIEW V_PEPTIDE AS
-- exclude peptide decoys and contaminants as identified by MaxQuant
SELECT
    pep_id,
    raw_file,
    seq,
    LENGTH(seq) AS seq_len, -- peptide sequence length
    mods,
    charge,
    mass,
    retime,
    pep_score,
    res_fwhm
FROM
    PEPTIDE
WHERE
    is_decoy = 0 AND is_cont = 0;


--
-- View V_PROTEIN.
--

DROP VIEW IF EXISTS V_PROTEIN;
CREATE VIEW V_PROTEIN AS
-- PROTEIN table with extra columns
SELECT
    acc,
    id,
    evidence,
    CASE
        WHEN evidence = 1 THEN 'protein'
        WHEN evidence = 2 THEN 'transcript'
        WHEN evidence = 3 THEN 'homology'
        WHEN evidence = 4 THEN 'predicted'
        WHEN evidence = 5 THEN 'uncertain'
        ELSE 'undefined'
    END AS evidence_name, -- UniProtKB description of protein existence (evidence) numbers
    gene,
    CASE
        WHEN db = 'tr' THEN 'UniProtKB/TrEMBL'
        WHEN db = 'sp' THEN 'UniProtKB/Swiss-Prot'
        ELSE 'User'
    END AS db,
    des,
    org,
    seq,
    LENGTH(seq) AS seq_len -- protein sequence length
FROM
    PROTEIN;


--
-- View V_PGROUP.
--

DROP VIEW IF EXISTS V_PGROUP;
CREATE VIEW V_PGROUP AS
-- exclude protein (group) decoys and contaminants as identified by MaxQuant
SELECT
    grp_id,
    pep_score,
    id_by_site
FROM
    PGROUP
WHERE
    is_decoy = 0 AND is_cont = 0;


--
-- View V_PEPTIDE_QUANT.
--

DROP VIEW IF EXISTS V_PEPTIDE_QUANT;
CREATE VIEW V_PEPTIDE_QUANT AS
-- row-to-column transfored peptide quantitative data
SELECT
    pep_id,
    exp_name,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'INTENSITY H' THEN quant_value ELSE NULL END) AS NUMERIC) AS int_H,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'INTENSITY M' THEN quant_value ELSE NULL END) AS NUMERIC) AS int_M,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'INTENSITY L' THEN quant_value ELSE NULL END) AS NUMERIC) AS int_L,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO H/L' THEN quant_value ELSE NULL END) AS NUMERIC) AS raw_ratio_HL,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO H/M' THEN quant_value ELSE NULL END) AS NUMERIC) AS raw_ratio_HM,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO M/L' THEN quant_value ELSE NULL END) AS NUMERIC) AS raw_ratio_ML,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO H/L NORMALIZED' THEN quant_value ELSE NULL END) AS NUMERIC) AS norm_ratio_HL,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO H/M NORMALIZED' THEN quant_value ELSE NULL END) AS NUMERIC) AS norm_ratio_HM,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO M/L NORMALIZED' THEN quant_value ELSE NULL END) AS NUMERIC) AS norm_ratio_ML
FROM
    PEPTIDE_QUANT
GROUP BY
    pep_id, exp_name;


--
-- View VV_PEPTIDE_QUANT.
--

DROP VIEW IF EXISTS VV_PEPTIDE_QUANT;
CREATE VIEW VV_PEPTIDE_QUANT AS
-- V_PEPTIDE_QUANT with extra columns incl. reciprocal ratios and fold-changes
SELECT
    pep_id,
    exp_name,
    int_H,
    int_M,
    int_L,
    ROUND(raw_ratio_HL, 4) AS raw_ratio_HL,
    ROUND(1 / raw_ratio_HL, 4) AS raw_ratio_LH,
    ROUND(raw_ratio_HM, 4) AS raw_ratio_HM,
    ROUND(1 / raw_ratio_HM, 4) AS raw_ratio_MH,
    ROUND(raw_ratio_ML, 4) AS raw_ratio_ML,
    ROUND(1 / raw_ratio_ML, 4) AS raw_ratio_LM,
    ROUND(norm_ratio_HL, 4) AS norm_ratio_HL,
    ROUND(1 / norm_ratio_HL, 4) AS norm_ratio_LH,
    ROUND(norm_ratio_HM, 4) AS norm_ratio_HM,
    ROUND(1 / norm_ratio_HM, 4) AS norm_ratio_MH,
    ROUND(norm_ratio_ML, 4) AS norm_ratio_ML,
    ROUND(1 / norm_ratio_ML, 4) AS norm_ratio_LM,
    CASE WHEN norm_ratio_HL < 1 THEN ROUND(1 / norm_ratio_HL, 4) ELSE norm_ratio_HL END AS fc_HL,
    CASE WHEN norm_ratio_HL >= 1 THEN norm_ratio_HL ELSE ROUND(1 / norm_ratio_HL, 4) END AS fc_LH,
    CASE WHEN norm_ratio_HM < 1 THEN ROUND(1 / norm_ratio_HM, 4) ELSE norm_ratio_HM END AS fc_HM,
    CASE WHEN norm_ratio_HM >= 1 THEN norm_ratio_HM ELSE ROUND(1 / norm_ratio_HM, 4) END AS fc_MH,
    CASE WHEN norm_ratio_ML < 1 THEN ROUND(1 / norm_ratio_ML, 4) ELSE norm_ratio_ML END AS fc_ML,
    CASE WHEN norm_ratio_ML >= 1 THEN norm_ratio_ML ELSE ROUND(1 / norm_ratio_ML, 4) END AS fc_LM
FROM
    V_PEPTIDE_QUANT;


--
-- View V_PGROUP_QUANT.
--

DROP VIEW IF EXISTS V_PGROUP_QUANT;
CREATE VIEW V_PGROUP_QUANT AS
-- row-to-column transformed protein (group) quantitative data
-- Note: MaxQuant reports coefficient of variation (%CV) for each protein group
-- calculated as 100 * standard deviation (SD) of log-transformed peptide ratios
SELECT
    grp_id,
    exp_name,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'INTENSITY H' THEN quant_value ELSE NULL END) AS NUMERIC) AS int_H,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'INTENSITY M' THEN quant_value ELSE NULL END) AS NUMERIC) AS int_M,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'INTENSITY L' THEN quant_value ELSE NULL END) AS NUMERIC) AS int_L,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO H/L' THEN quant_value ELSE NULL END) AS NUMERIC) AS raw_ratio_HL,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO H/M' THEN quant_value ELSE NULL END) AS NUMERIC) AS raw_ratio_HM,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO M/L' THEN quant_value ELSE NULL END) AS NUMERIC) AS raw_ratio_ML,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO H/L NORMALIZED' THEN quant_value ELSE NULL END) AS NUMERIC) AS norm_ratio_HL,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO H/M NORMALIZED' THEN quant_value ELSE NULL END) AS NUMERIC) AS norm_ratio_HM,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO M/L NORMALIZED' THEN quant_value ELSE NULL END) AS NUMERIC) AS norm_ratio_ML,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO H/L NORMALIZED SIGNIFICANCE B' THEN quant_value ELSE NULL END) AS NUMERIC) AS sig_ratio_HL,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO H/M NORMALIZED SIGNIFICANCE B' THEN quant_value ELSE NULL END) AS NUMERIC) AS sig_ratio_HM,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO M/L NORMALIZED SIGNIFICANCE B' THEN quant_value ELSE NULL END) AS NUMERIC) AS sig_ratio_ML,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO H/L VARIABILITY [%]' THEN quant_value ELSE NULL END) AS NUMERIC) AS var_ratio_HL,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO H/M VARIABILITY [%]' THEN quant_value ELSE NULL END) AS NUMERIC) AS var_ratio_HM,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO M/L VARIABILITY [%]' THEN quant_value ELSE NULL END) AS NUMERIC) AS var_ratio_ML,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO H/L COUNT' THEN quant_value ELSE NULL END) AS NUMERIC) AS n_pep_qts_HL,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO H/M COUNT' THEN quant_value ELSE NULL END) AS NUMERIC) AS n_pep_qts_HM,
    CAST(GROUP_CONCAT(CASE WHEN quant_type = 'RATIO M/L COUNT' THEN quant_value ELSE NULL END) AS NUMERIC) AS n_pep_qts_ML
FROM
    PGROUP_QUANT
GROUP BY
    grp_id, exp_name;


--
-- View VV_PGROUP_QUANT.
--

DROP VIEW IF EXISTS VV_PGROUP_QUANT;
CREATE VIEW VV_PGROUP_QUANT AS
-- V_PGROUP_QUANT with extra columns:
-- number of peptide quantitations, PEP score, reciprocal ratios, fold-changes, standard deviations and significance B
-- excludes protein groups identified as contaminants and/or decoys
--
SELECT
    A.grp_id,
    exp_name,
    pep_score,
    int_H,
    int_M,
    int_L,
    n_pep_qts_HL,
    n_pep_qts_HL AS n_pep_qts_LH,
    n_pep_qts_HM,
    n_pep_qts_HM AS n_pep_qts_MH,
    n_pep_qts_ML,
    n_pep_qts_ML AS n_pep_qts_LM,
    ROUND(raw_ratio_HL, 4) AS raw_ratio_HL,
    ROUND(1 / raw_ratio_HL, 4) AS raw_ratio_LH,
    ROUND(raw_ratio_HM, 4) AS raw_ratio_HM,
    ROUND(1 / raw_ratio_HM, 4) AS raw_ratio_MH,
    ROUND(raw_ratio_ML, 4) AS raw_ratio_ML,
    ROUND(1 / raw_ratio_ML, 4) AS raw_ratio_LM,
    ROUND(norm_ratio_HL, 4) AS norm_ratio_HL,
    ROUND(1 / norm_ratio_HL, 4) AS norm_ratio_LH,
    ROUND(norm_ratio_HM, 4) AS norm_ratio_HM,
    ROUND(1 / norm_ratio_HM, 4) AS norm_ratio_MH,
    ROUND(norm_ratio_ML, 4) AS norm_ratio_ML,
    ROUND(1 / norm_ratio_ML, 4) AS norm_ratio_LM,
    ROUND(var_ratio_HL / 100, 4) AS sd_ratio_HL, -- standard deviation of peptide ratios
    ROUND(var_ratio_HL / 100, 4) AS sd_ratio_LH, -- sd_ratio_XY = sd_ratio_YX
    ROUND(var_ratio_HM / 100, 4) AS sd_ratio_HM,
    ROUND(var_ratio_HM / 100, 4) AS sd_ratio_MH,
    ROUND(var_ratio_ML / 100, 4) AS sd_ratio_ML,
    ROUND(var_ratio_ML / 100, 4) AS sd_ratio_LM,
    CASE WHEN norm_ratio_HL < 1 THEN ROUND(1 / norm_ratio_HL, 4) ELSE norm_ratio_HL END AS fc_HL, -- fold-change of protein ratio
    CASE WHEN norm_ratio_HL >= 1 THEN norm_ratio_HL ELSE ROUND(1 / norm_ratio_HL, 4) END AS fc_LH,
    CASE WHEN norm_ratio_HM < 1 THEN ROUND(1 / norm_ratio_HM, 4) ELSE norm_ratio_HM END AS fc_HM,
    CASE WHEN norm_ratio_HM >= 1 THEN norm_ratio_HM ELSE ROUND(1 / norm_ratio_HM, 4) END AS fc_MH,
    CASE WHEN norm_ratio_ML < 1 THEN ROUND(1 / norm_ratio_ML, 4) ELSE norm_ratio_ML END AS fc_ML,
    CASE WHEN norm_ratio_ML >= 1 THEN norm_ratio_ML ELSE ROUND(1 / norm_ratio_ML, 4) END AS fc_LM,
    CASE WHEN norm_ratio_HL IS NULL THEN NULL ELSE ROUND(sig_ratio_HL, 4) END AS sig_ratio_HL, -- significance B of protein ratio
    CASE WHEN norm_ratio_HL IS NULL THEN NULL ELSE ROUND(sig_ratio_HL, 4) END AS sig_ratio_LH, -- sig_ratio_XY = sig_ratio_YX
    CASE WHEN norm_ratio_HM IS NULL THEN NULL ELSE ROUND(sig_ratio_HM, 4) END AS sig_ratio_HM,
    CASE WHEN norm_ratio_HM IS NULL THEN NULL ELSE ROUND(sig_ratio_HM, 4) END AS sig_ratio_MH,
    CASE WHEN norm_ratio_ML IS NULL THEN NULL ELSE ROUND(sig_ratio_ML, 4) END AS sig_ratio_ML,
    CASE WHEN norm_ratio_ML IS NULL THEN NULL ELSE ROUND(sig_ratio_ML, 4) END AS sig_ratio_LM
FROM
    V_PGROUP A, V_PGROUP_QUANT B
WHERE
   A.grp_id = B.grp_id;


--
-- View V_PEPTIDE_STAT.
--

DROP VIEW IF EXISTS V_PEPTIDE_STAT;
CREATE VIEW V_PEPTIDE_STAT AS
-- show a summary of peptide identifications & quantitations per experiment
SELECT
    exp_name,
    COUNT(CASE WHEN is_decoy = 0 AND is_cont = 0 THEN A.pep_id ELSE NULL END) AS n_pep_ids,
    COUNT(CASE WHEN has_ratio AND is_decoy = 0 AND is_cont = 0 THEN A.pep_id ELSE NULL END) AS n_pep_qts,
    COUNT(DISTINCT CASE WHEN is_decoy = 0 AND is_cont = 0 THEN seq || ':' || IFNULL(mods,'') ELSE NULL END) AS 'n_unq_pep_seq+mod_ids',
    COUNT(DISTINCT CASE WHEN has_ratio AND is_decoy = 0 AND is_cont = 0 THEN seq || ':' || IFNULL(mods, '') ELSE NULL END) AS 'n_unq_pep_seq+mod_qts',
    COUNT(DISTINCT CASE WHEN is_decoy = 0 AND is_cont = 0 THEN seq ELSE NULL END) AS n_unq_pep_seq_ids,
    COUNT(DISTINCT CASE WHEN has_ratio AND is_decoy = 0 AND is_cont = 0 THEN seq ELSE NULL END) AS n_unq_pep_seq_qts,
    COUNT(CASE WHEN is_decoy = 1 THEN A.pep_id ELSE NULL END) AS n_pep_ids_decoys,
    COUNT(CASE WHEN is_cont = 1 THEN A.pep_id ELSE NULL END) AS n_pep_ids_conts,
    COUNT(DISTINCT CASE WHEN is_decoy = 1 THEN seq ELSE NULL END) AS n_unq_pep_seq_decoys,
    COUNT(DISTINCT CASE WHEN is_cont = 1 THEN seq ELSE NULL END) AS n_unq_pep_seq_conts
FROM
    PEPTIDE A,
    (SELECT
        pep_id,
        exp_name,
        CASE WHEN MAX(CAST(quant_value AS NUMERIC)) > 0 THEN 1 ELSE 0 END AS has_ratio
    FROM
        PEPTIDE_QUANT
    WHERE
        quant_type LIKE 'RATIO%'
    GROUP BY
        pep_id, exp_name) B
WHERE
    A.pep_id = B.pep_id
GROUP BY
    exp_name;


--
-- View V_PROTEIN_STAT.
--

DROP VIEW IF EXISTS V_PROTEIN_STAT;
CREATE VIEW V_PROTEIN_STAT AS
-- show a summary of database-dependent protein identifications including evidence (protein existence)
-- exclude protein accessions which belong to protein groups identified as contaminants/decoys
SELECT
    db,
    COUNT(*) AS n_prot_acc,
    COUNT(prot_acc) AS n_prot_ids,
    COUNT(CASE WHEN evidence = 1 THEN acc ELSE NULL END) AS n_prot_acc_evid_protein,
    COUNT(CASE WHEN evidence = 2 THEN acc ELSE NULL END) AS n_prot_acc_evid_transcript,
    COUNT(CASE WHEN evidence = 3 THEN acc ELSE NULL END) AS n_prot_acc_evid_homology,
    COUNT(CASE WHEN evidence = 4 THEN acc ELSE NULL END) AS n_prot_acc_evid_predicted,
    COUNT(CASE WHEN evidence = 5 THEN acc ELSE NULL END) AS n_prot_acc_evid_uncertain
FROM
    V_PROTEIN A
    LEFT JOIN (PROT2GRP B INNER JOIN V_PGROUP C ON B.grp_id = C.grp_id) D ON A.acc = D.prot_acc
GROUP BY
    db;


--
-- View V_PGROUP_STAT.
--

DROP VIEW IF EXISTS V_PGROUP_STAT;
CREATE VIEW V_PGROUP_STAT AS
-- show a summary of non-redundant protein identifications & quantitations
SELECT
    exp_name,
    COUNT(CASE WHEN is_decoy = 0 AND is_cont = 0 THEN A.grp_id ELSE NULL END) AS n_pgrp_ids,
    COUNT(CASE WHEN (norm_ratio_HL IS NOT NULL OR norm_ratio_HM IS NOT NULL OR norm_ratio_ML IS NOT NULL) AND is_decoy = 0 AND is_cont = 0 THEN A.grp_id ELSE NULL END) AS n_pgrp_qts,
    COUNT(CASE WHEN id_by_site = 1 AND is_decoy = 0 AND is_cont = 0 THEN A.grp_id ELSE NULL END) AS n_pgrp_ids_by_site,
    COUNT(CASE WHEN is_decoy = 1 THEN A.grp_id ELSE NULL END) AS n_pgrp_decoys,
    COUNT(CASE WHEN is_cont = 1 THEN A.grp_id ELSE NULL END) AS n_pgrp_conts
FROM
    PGROUP A, V_PGROUP_QUANT B
WHERE
    A.grp_id = B.grp_id
GROUP BY
    exp_name;


--
-- View V_REG_PGROUP_STAT.
--

DROP VIEW IF EXISTS V_REG_PGROUP_STAT;
CREATE VIEW V_REG_PGROUP_STAT AS
-- show a summary of potentially regulated (non-redundant) proteins given cutoffs:
-- FC >= 1.5 and P-value < .05; the latter cutoff used only if P-values are provided
SELECT
    exp_name,
    COUNT(CASE WHEN ((fc_HL >= 1.5 AND IFNULL(sig_ratio_HL, 0) < 0.05) OR (fc_HM >= 1.5 AND IFNULL(sig_ratio_HM, 0) < 0.05) OR (fc_ML >= 2 AND IFNULL(sig_ratio_ML, 0) < 0.05)) THEN grp_id ELSE NULL END) AS n_pgrp_ids,
    COUNT(CASE WHEN fc_HL >= 1.5 AND IFNULL(sig_ratio_HL, 0) < 0.05 THEN grp_id ELSE NULL END) AS 'n_pgrp_ids_H/L+L/H',
    COUNT(CASE WHEN norm_ratio_HL >= 1.5 AND IFNULL(sig_ratio_HL, 0) < 0.05 THEN grp_id ELSE NULL END) AS 'n_pgrp_ids_H/L',
    COUNT(CASE WHEN norm_ratio_LH >= 1.5 AND IFNULL(sig_ratio_HL, 0) < 0.05 THEN grp_id ELSE NULL END) AS 'n_pgrp_ids_L/H',
    COUNT(CASE WHEN fc_HM >= 1.5 AND IFNULL(sig_ratio_HM, 0) < 0.05 THEN grp_id ELSE NULL END) AS 'n_pgrp_ids_H/M+M/H',
    COUNT(CASE WHEN norm_ratio_HM >= 1.5 AND IFNULL(sig_ratio_HM, 0) < 0.05 THEN grp_id ELSE NULL END) AS 'n_pgrp_ids_H/M',
    COUNT(CASE WHEN norm_ratio_MH >= 1.5 AND IFNULL(sig_ratio_HM, 0) < 0.05 THEN grp_id ELSE NULL END) AS 'n_pgrp_ids_M/H',
    COUNT(CASE WHEN fc_ML >= 1.5 AND IFNULL(sig_ratio_ML, 0) < 0.05 THEN grp_id ELSE NULL END) AS 'n_pgrp_ids_M/L+L/M',
    COUNT(CASE WHEN norm_ratio_ML >= 1.5 AND IFNULL(sig_ratio_ML, 0) < 0.05 THEN grp_id ELSE NULL END) AS 'n_pgrp_ids_M/L',
    COUNT(CASE WHEN norm_ratio_LM >= 1.5 AND IFNULL(sig_ratio_ML, 0) < 0.05 THEN grp_id ELSE NULL END) AS 'n_pgrp_ids_L/M'
FROM
    VV_PGROUP_QUANT
GROUP BY
    exp_name;


--
-- View V_PGROUP_MEMBER.
--

DROP VIEW IF EXISTS V_PGROUP_MEMBERS;
CREATE VIEW V_PGROUP_MEMBERS AS
-- show the entries in the searchable grid
SELECT
    E.grp_id,
    E.grp_size,
    exp_name,
    prot_accs,
    prot_names,
    CASE
       WHEN evidence = 1 THEN 'protein'
       WHEN evidence = 2 THEN 'transcript'
       WHEN evidence = 3 THEN 'homology'
       WHEN evidence = 4 THEN 'predicted'
       WHEN evidence = 5 THEN 'uncertain'
       ELSE 'unknown'
    END AS grp_evidence, 
    gene_names,
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
FROM
    (SELECT
        grp_id,
        COUNT(acc) AS grp_size,                                                 -- protein group size
        '"' || GROUP_CONCAT(REPLACE(des, '"', ''), '","') || '"' AS prot_names, -- list of protein names (annotations)
        GROUP_CONCAT(db || ':' || acc) AS prot_accs,                            -- list of db:accessions
        GROUP_CONCAT(DISTINCT gene) AS gene_names,                              -- list of unique gene names
        MIN(IFNULL(evidence, 6)) AS evidence,                                   -- best protein evidence in the group
        org
    FROM
        (SELECT
            A.grp_id,
            db,
            acc,
            des,
            gene,
            evidence,
            org
        FROM
            PROT2GRP A, V_PROTEIN B
        WHERE
            A.prot_acc = B.acc
        ORDER BY
            grp_id, db) D
    GROUP BY grp_id) E, VV_PGROUP_QUANT F
WHERE
    E.grp_id = F.grp_id;


---
--- View V_PEP2GRP.
---

DROP VIEW IF EXISTS V_PEP2GRP;
CREATE VIEW V_PEP2GRP AS
-- view used for the peptide coverage map
SELECT
    grp_id,
    B.prot_acc,
    lead_prot,
    db,
    gene,
    des,
    A.pep_id,
    exp_name,
    A.seq AS pep_seq,
    C.seq AS prot_seq,
    C.seq_len AS prot_len
FROM
    V_PEPTIDE A, PEP2PROT B, V_PROTEIN C, PROT2GRP D, EXPERIMENT E
WHERE
    A.pep_id = B.pep_id
    AND B.prot_acc = C.acc
    AND C.acc = D.prot_acc
    AND E.raw_file = A.raw_file;


-- 
-- View V_UNMAPPED_PROT2GRP.
--

DROP VIEW IF EXISTS V_UNMAPPED_PROT2GRP;
CREATE VIEW V_UNMAPPED_PROT2GRP AS
-- view 'unmapped' protein accessions present in the uploaded 'proteinGroups.txt' file (or PROT2GRP table) but not in the FASTA sequence library (or PROTEIN table)
SELECT
    DISTINCT prot_acc
FROM
    PROT2GRP A LEFT JOIN PROTEIN B
ON
    A.prot_acc = B.acc
WHERE
    acc IS NULL;


-- 
-- View V_UNMAPPED_PEP2PROT.
--

DROP VIEW IF EXISTS V_UNMAPPED_PEP2PROT;
CREATE VIEW V_UNMAPPED_PEP2PROT AS
-- view 'unmapped' protein accessions present in the uploaded 'evidence.txt' file (or PEP2PROT table) but not in the FASTA sequence library (or PROTEIN table)
SELECT
    DISTINCT prot_acc
FROM
    PEP2PROT A LEFT JOIN PROTEIN B
ON
    A.prot_acc = B.acc
WHERE
    acc IS NULL;


---
--- View V_UNMAPPED_PROTEIN_STAT.
---

DROP VIEW IF EXISTS V_UNMAPPED_PROTEIN_STAT;
-- view the numbers of (un)mapped protein accessions to identify data integrity problems
CREATE VIEW V_UNMAPPED_PROTEIN_STAT AS
SELECT
    n_prot_acc,                 -- number of protein accessions in the FASTA sequence library (or PROTEIN table)
    n_prot_acc_link_pgrp_ids,   -- number of protein accessions in linked to protein groups, i.e. found in 'proteinGroups.txt' file (or PGROUP table)
    n_prot_acc_unlink_pgrp_ids, -- number of (unmapped) protein accessions not linked to protein groups,  i.e. found in 'proteinGroups.txt' file (or PGROUP table) but not the FASTA library
    n_prot_acc_link_pep_ids,    -- number of protein accessions linked to peptide IDs, i.e. found in 'evidence.txt' file (or PEP2PROT table)

    n_prot_acc_unlink_pep_ids   -- number of (unmapped) protein accessions not linked to peptide IDs, i.e. found in 'evidence.txt' file (or PEP2PROT table) but not the FASTA library

FROM
    ((SELECT COUNT(*) n_prot_acc FROM PROTEIN),
    (SELECT COUNT(*) n_prot_acc_link_pgrp_ids FROM PROT2GRP),
    (SELECT COUNT(*) n_prot_acc_unlink_pgrp_ids FROM V_UNMAPPED_PROT2GRP),
    (SELECT COUNT(DISTINCT prot_acc) n_prot_acc_link_pep_ids FROM PEP2PROT),
    (SELECT COUNT(DISTINCT prot_acc) n_prot_acc_unlink_pep_ids FROM V_UNMAPPED_PEP2PROT));
