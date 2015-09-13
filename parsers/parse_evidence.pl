#!/usr/bin/perl
#
# This script parses the MaxQuant 'evidence.txt' result file.
# Both duplex and triplex SILAC experiments are supported.
# 
# Parsed columns:
#   Modified sequence
#   Proteins
#   Leadning Proteins
#   Raw File
#   Charge
#   Mass
#   PEP
#   Ratio H/L
#   Ratio H/L Normalized
#   Ratio H/M
#   Ratio H/M Normalized
#   Ratio M/L
#   Ratio M/L Normalized
#   Intensity L
#   Intensity H
#   Intensity M
#   Resolution
#   Reverse
#   Contaminant
#   Calibrated Retention Time
#
# Notes:
#   The fields in the input file are parsed in an order-independent manner.
#   The output files correspond to the tables in the PIQMIe database schema.
#   Make sure that the input file has UNIX Line Feed, otherwise use the dos2unix utility.
#
#
# Author: Arnold Kuzniar
# Version: 1.0
#

use strict;
use warnings;
use Cwd 'abs_path';
use File::Basename;
use File::Find;
use File::Spec::Functions;

$, = "\t";
$\ = "\n";

my $MAXQUANT_DIR = shift;
my $infile = 'evidence.txt';
my $pid = 0;          # Note: peptide ID is NOT RESET when parsing new file
my $n_proc_files = 0; # count the number of processed files
my $null = '\N';      # change this depending on RDBMS: in MySQL '\N' becomes NULL but not in SQLite!

die "$0 [MaxQuant DIR]\n" unless $MAXQUANT_DIR and -e $MAXQUANT_DIR;

find(\&ProcessFile, $MAXQUANT_DIR);

unless ($n_proc_files) {
    print STDERR "Error: No input file '$infile' was found in the '$MAXQUANT_DIR' directory.";
    exit 1;
} else {
    print "Input files processed: $n_proc_files";
    unless ($pid) {
        print STDERR "Error: No peptides found in '$MAXQUANT_DIR/$infile' file.";
        exit 1;
    }
}

sub ProcessFile {
    return unless $_ eq $infile;
    my $col_idx = 0;
    my $i = 0;
    my $filepath = abs_path($_);
    my $base_dir = dirname($filepath);
    my $peptide_file = catfile($base_dir, 'PEPTIDE.dat');
    my $pep2prot_file = catfile($base_dir, 'PEP2PROT.dat');
    my $experiment_file = catfile($base_dir, 'EXPERIMENT.dat');
    my $quant_file = catfile($base_dir, 'PEPTIDE_QUANT.dat');
    my %experiments;
    my @silac_cols;
    my $header_ln;
    my %header = (
      'MODIFIED SEQUENCE'     => undef,
      'PROTEINS'              => undef,
      'LEADING PROTEINS'      => undef,
      'LEADING RAZOR PROTEIN' => undef,
      'EXPERIMENT'            => undef,
      'RAW FILE'              => undef,
      'CHARGE'                => undef,
      'MASS'                  => undef,
      'PEP'                   => undef,
      'RATIO H/L'             => undef,
      'RATIO H/L NORMALIZED'  => undef,
      'RATIO M/L'             => undef,
      'RATIO M/L NORMALIZED'  => undef,
      'RATIO H/M'             => undef,
      'RATIO H/M NORMALIZED'  => undef,
      'INTENSITY H'           => undef,
      'INTENSITY M'           => undef,
      'INTENSITY L'           => undef,
      'RESOLUTION'            => undef,
      'REVERSE'               => undef,
      'CONTAMINANT'           => undef,
      'CALIBRATED RETENTION TIME' => undef,
    );

    open IN, $filepath or die "Cannot open file '$filepath':$!\n";
    print "Parsing \"$filepath\" file";

    # first line must be header
    # store column names in a lookup table
    $header_ln = <IN>;
    chomp $header_ln;

    foreach my $col(split(/\t/, uc($header_ln))) {
        if(exists $header{$col}) {
            $header{$col} = $col_idx;
            # select columns with SILAC ratios and intensities
            push(@silac_cols, $col) if $col =~ /^RATIO|^INTENSITY/;
            $i++;
        }
        $col_idx++;  
    }

    # check the file format
    unless ($i) {
        printf STDERR "Error: Uploaded peptide list has unsupported file format!";
        exit 1;
    }

    # write db table files
    open PEPTIDE, ">", $peptide_file or die "Cannot write '$peptide_file':$!\n";
    open PEP2PROT, ">", $pep2prot_file or die "Cannot write '$pep2prot_file':$!\n";
    open EXPERIMENT, ">", $experiment_file or die "Cannot write '$experiment_file':$!\n";
    open PEPTIDE_QUANT, ">", $quant_file or die "Cannot write '$quant_file':$!\n";

    # parse file
    while (<IN>) {
        next if /^#|^modified/i; # skip comment line or header line
        chomp;
        my @cols = split/\t/;
        my ($pep_id,
            $seq,
            $prots,
            $res_fwhm,
            $lead_prots,
            $lead_razor_prot,
            $exp_name,
            $raw_file,
            $charge,
            $mass,
            $retime,
            $pep_score,
            $raw_ratio_HL,
            $raw_ratio_HM,
            $raw_ratio_ML,
            $norm_ratio_HL,
            $norm_ratio_HM,
            $norm_ratio_ML,
            $int_H,
            $int_M,
            $int_L,
            $is_decoy,
            $is_cont
        );

        $pid++ if @cols;

        # set variables to $null if columns do not exist
        $seq = (defined $header{'MODIFIED SEQUENCE'}) ? $cols[$header{'MODIFIED SEQUENCE'}] : $null;
        $prots = (defined $header{'PROTEINS'}) ? $cols[$header{'PROTEINS'}] : $null;
        $lead_prots = (defined $header{'LEADING PROTEINS'}) ? $cols[$header{'LEADING PROTEINS'}] : $null;
        $lead_razor_prot = (defined $header{'LEADING RAZOR PROTEIN'}) ? $cols[$header{'LEADING RAZOR PROTEIN'}] : $null;
        $exp_name = (defined $header{'EXPERIMENT'}) ? uc($cols[$header{'EXPERIMENT'}]) : $null;
        $raw_file = (defined $header{'RAW FILE'}) ? $cols[$header{'RAW FILE'}] : $null;
        $charge = (defined $header{'CHARGE'}) ? $cols[$header{'CHARGE'}] : $null;
        $mass = (defined $header{'MASS'}) ? $cols[$header{'MASS'}] : $null;
        $retime = (defined $header{'CALIBRATED RETENTION TIME'}) ? $cols[$header{'CALIBRATED RETENTION TIME'}] : $null;
        $pep_score = (defined $header{'PEP'}) ? $cols[$header{'PEP'}] : $null;
        $raw_ratio_HL = (defined $header{'RATIO H/L'}) ? $cols[$header{'RATIO H/L'}] : $null;
        $raw_ratio_HM = (defined $header{'RATIO H/M'}) ? $cols[$header{'RATIO H/M'}] : $null;
        $raw_ratio_ML = (defined $header{'RATIO M/L'}) ? $cols[$header{'RATIO M/L'}] : $null;
        $norm_ratio_HL = (defined $header{'RATIO H/L NORMALIZED'}) ? $cols[$header{'RATIO H/L NORMALIZED'}] : $null;
        $norm_ratio_HM = (defined $header{'RATIO H/M NORMALIZED'}) ? $cols[$header{'RATIO H/M NORMALIZED'}] : $null;
        $norm_ratio_ML = (defined $header{'RATIO M/L NORMALIZED'}) ? $cols[$header{'RATIO M/L NORMALIZED'}] : $null;
        $int_H = (defined $header{'INTENSITY H'}) ? $cols[$header{'INTENSITY H'}] : $null;
        $int_M = (defined $header{'INTENSITY M'}) ? $cols[$header{'INTENSITY M'}] : $null;
        $int_L = (defined $header{'INTENSITY L'}) ? $cols[$header{'INTENSITY L'}] : $null;
        $res_fwhm = (defined $header{'RESOLUTION'}) ? $cols[$header{'RESOLUTION'}] : $null;
        $is_decoy = (defined $header{'REVERSE'}) ? $cols[$header{'REVERSE'}] : $null;
        $is_cont = (defined $header{'CONTAMINANT'}) ? $cols[$header{'CONTAMINANT'}] : $null;

        # post-process column values
        $pep_score = sprintf("%g", $pep_score) if $pep_score =~ /^\d+$/;
        $raw_ratio_HL = sprintf("%f", $raw_ratio_HL) if $raw_ratio_HL =~ /^\d+$/;
        $raw_ratio_HM = sprintf("%f", $raw_ratio_HM) if $raw_ratio_HM =~ /^\d+$/;
        $norm_ratio_ML = sprintf("%f", $raw_ratio_ML) if $raw_ratio_ML =~ /^\d+$/;
        $norm_ratio_HL = sprintf("%f", $norm_ratio_HL) if $norm_ratio_HL =~ /^\d+$/;
        $norm_ratio_HM = sprintf("%f", $norm_ratio_HM) if $norm_ratio_HM =~ /^\d+$/;
        $norm_ratio_ML = sprintf("%f", $norm_ratio_ML) if $norm_ratio_ML =~ /^\d+$/;
        $int_H = sprintf("%d", $int_H) if $int_H =~ /^d+$/;
        $int_M = sprintf("%d", $int_M) if $int_M =~ /^d+$/;
        $int_L = sprintf("%d", $int_L) if $int_M =~ /^d+$/;
        $res_fwhm =  sprintf("%f", $res_fwhm) if $res_fwhm =~ /^d+$/;
        $is_decoy = ($is_decoy eq '+') ? 1 : 0;
        $is_cont = ($is_cont eq '+') ? 1 : 0;

        $pep_id = sprintf("%06d", $pid); # zero-padded peptide IDs 'xxxxxx'

        # collect data for EXPERIMENT table
        $experiments{$raw_file}{$exp_name} = undef;

        # parse modification from the modified sequences
        # Input sequence:
        #    _YYIHDISDIIDQC(ne)CDIGY(ph)HAS(ph)INR_
        # Output sequence:
        #    YYIHDISDIIDQCCDIGYHASINR
        # Output PTMs including target site/aa and positions:
        #    ne(C):13 ph(Y):18 ph(S):21
        my (%mods, @mods, $mods);
        my $org_seq = $seq;

        $seq =~ s/_//g; # remove leading/trailing '_'
        while ($seq =~ /\((\w+)\)/g) {
            my $mod_code = $1;
            my $mod_pos = $-[0];
            my $mod_aa = '-';
            my $offset = $mod_pos - 1;

            if ($mod_pos == 0) {
                $mod_pos = 1; # set the position of N-terminal modification to 1 instead of 0
                $offset = length($mod_code) + $mod_pos + 1;
            }
            $mod_aa = substr($seq, $offset, 1); # store the modified amino acid
            push(@{$mods{"$mod_code($mod_aa)"}}, $mod_pos); # store modified aa and position 
            $seq =~ s/\(\w+\)//; # clear sequence from modifications
        }

        foreach my $mod(sort keys %mods) {
            my $str = sprintf("%s:%s", $mod, join(",", @{$mods{$mod}})); 
            push(@mods, $str);
        }
        $mods = join(" ", @mods);
        $mods = $null unless $mods;

        # Write data files:
        # Note: the order of variables must follow the order of the table columns
        #   PEPTIDE table data
        print PEPTIDE
            $pep_id,
            $raw_file,
            $seq,
            $mods,
            $charge,
            $mass,
            $retime,
            $pep_score,
            $res_fwhm,
            $is_decoy,
            $is_cont;

        #   PEPTIDE_QUANT table data
        foreach my $col(@silac_cols) {
            my $quant_type = $col;
            my $quant_value = $cols[$header{$col}];

            # Post-process column values:
            #   replace 'NA', 'NaN' or '' by $null 
            $quant_value = $null if $quant_value =~ /na/i or not defined $quant_value;

            print PEPTIDE_QUANT
                $pep_id,
                $exp_name,
                $quant_type,
                $quant_value;
        } 

        #   PEP2PROT table data:
        #     Exclude any protein accession with CON__ or REV__ prefix.
        #     Handle leading (razor) proteins by setting the lead_prot variable to:
        #       0 = not a leading protein
        #       1 = leading protein
        #       2 = leading razor protein
        my %tmp = map { $_ => 1 } split(/;\s*/, $lead_prots);
        $tmp{$lead_razor_prot}++;

        foreach my $prot_acc(split(/;\s*/, $prots)) {
            next if $prot_acc =~ /CON_|REV_/i;
            my $lead_prot = (exists $tmp{$prot_acc}) ? $tmp{$prot_acc} : 0;

            print PEP2PROT
                $pep_id,
                $prot_acc,
                $lead_prot;
        }
    }
    close IN;
    close PEPTIDE;
    close PEP2PROT;
    close PEPTIDE_QUANT;

    # Write data file:
    #   EXPERIMENT table data
    foreach my $raw_file(keys %experiments) {
        foreach my $exp_name(keys %{$experiments{$raw_file}}) {
            print EXPERIMENT $raw_file, $exp_name;
        }
    }
    close EXPERIMENT;

    $n_proc_files++;

    if (-z $quant_file) {
        printf(STDERR "Error: No SILAC peptide quantitations found in MaxQuant '%s' file. Thus, '%s' table file is empty!\n", $infile, basename($quant_file));
        exit 1;
    }
}
