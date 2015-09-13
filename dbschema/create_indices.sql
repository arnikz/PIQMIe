--
-- Written by: Arnold Kuzniar
--
-- Last update: 21/12/2014
--

--
-- Create table indices
--

CREATE INDEX idx_PEPTIDE_seq ON PEPTIDE(seq);
CREATE INDEX idx_PEPTIDE_mods ON PEPTIDE(mods);
CREATE INDEX idx_PEPTIDE_raw_file ON PEPTIDE(raw_file);
CREATE INDEX idx_PROTEIN_id ON PROTEIN(id);
CREATE INDEX idx_PROTEIN_evidence ON PROTEIN(evidence);
CREATE INDEX idx_PROTEIN_gene ON PROTEIN(gene);
CREATE INDEX idx_PROTEIN_db ON PROTEIN(db);
CREATE INDEX idx_PROTEIN_des ON PROTEIN(des);
CREATE INDEX idx_PEP2PROT_prot_acc ON PEP2PROT(prot_acc);
CREATE INDEX idx_EXPERIMENT_exp_name ON EXPERIMENT(exp_name);
CREATE INDEX idx_PEPTIDE_QUANT_pep_id ON PEPTIDE_QUANT(pep_id, exp_name);
CREATE INDEX idx_PEPTIDE_QUANT_quant ON PEPTIDE_QUANT(quant_type, quant_value);
CREATE INDEX idx_PEPTIDE_QUANT_exp_name ON PEPTIDE_QUANT(exp_name);
CREATE INDEX idx_PGROUP_QUANT_grp_id ON PGROUP_QUANT(grp_id, exp_name);
CREATE INDEX idx_PGROUP_QUANT_quant ON PGROUP_QUANT(quant_type, quant_value);
CREATE INDEX idx_PGROUP_QUANT_exp_name ON PGROUP_QUANT(exp_name);
