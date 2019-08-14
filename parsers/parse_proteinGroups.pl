#!/usr/bin/env perl
#
# This script parses the MaxQuant 'proteinGroups.txt' file or its post-processed version.
# Both duplex and triplex SILAC experiments are supported.
#
# Parsed columns:
#   Protein IDs
#   PEP
#   Ratio H/L ...
#   Ratio H/L normalized ...
#   Ratio H/L variability [%] ...
#   Ratio H/L count ...
#   Ratio H/M ...
#   Ratio H/M normalized ...
#   Ratio H/M variability [%] ...
#   Ratio H/M count ...
#   Ratio M/L ...
#   Ratio M/L normalized ...
#   Ratio M/L variability [%] ...
#   Ratio M/L count ...
#   Intensity L ...
#   Intensity H ...
#   Intensity M ...
#   Reverse
#   Contaminant
#   *Ratio H/L normalized ... Significance B
#   *Ratio H/M normalized ... Significance B
#   *Ratio M/L normalized ... Significance B
#
# Notes:
#   '...' is a placeholder for experiment name in case of multi-experiment files
#   '*' indicates columns added by the Perseus software.
#
# The fields in the input file are parsed in an order-independent manner.
# The output files correspond to the tables in the PIQMIe database schema.
# Make sure that the input file has UNIX Line Feed, otherwise use the dos2unix utility.
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
my $infile = 'proteinGroups.txt';
my $gid = 0;
my $n_proc_files = 0; # count the number of processed files
my $null = '\N';      # change this depending on RDBMS: in MySQL '\N' becomes NULL but not in SQLite!
my $sep = '\t';

die "$0 [MaxQuant DIR]\n" unless $MAXQUANT_DIR and -e $MAXQUANT_DIR;

find(\&ProcessFile, $MAXQUANT_DIR);

unless ($n_proc_files) {
    print STDERR "Error: No input file '$infile' was found in the '$MAXQUANT_DIR' directory.";
    exit 1;
} else {
    print "Input files processed: $n_proc_files";
    unless ($gid) {
        print STDERR "Error: No protein groups found in '$MAXQUANT_DIR/$infile' file.";
        exit 1;
    }
}

sub ProcessFile {
    return unless $_ eq $infile;
    my $i = 0;
    my $filepath = abs_path($_);
    my $base_dir = dirname($filepath);
    my $pgroup_file = catfile($base_dir, 'PGROUP.dat');
    my $prot2grp_file = catfile($base_dir, 'PROT2GRP.dat');
    my $quant_file = catfile($base_dir, 'PGROUP_QUANT.dat');
    my @experiments;
    my %exp2cidx;
    my $header_line;
    my @col_names;
    my %header;

    open IN, $filepath or die "Cannot open file '$filepath':$!\n";
    print "Parsing \"$filepath\" file";

    # first line must be header with column names
    $header_line = <IN>;
    chomp $header_line;

    # store column names in a lookup table
    @col_names = split(/$sep/, uc($header_line));
    foreach my $col(@col_names) {
        $i++;
        next unless $col =~ /^PROTEIN IDS$|^PEP$|^RATIO|^INTENSITY\s+[LMH]\s+|SITE$|^REVERSE$|^CONTAMINANT$/;
        next if $col =~ /SIGNIFICANT/;
        # parse experiment name(s) e.g., in "INTENSITY L ..."
        # N.B.: only present when multiple experiments analyzed
        if ($col =~ /^INTENSITY\s+L\s+(?<name>.*)$/) {
            my $name = $+{name};
            push(@experiments, $name);
        }
        $header{$col} = $i - 1;
    }

    # check file format
    unless (keys %header) {
        printf STDERR "Error: Uploaded protein list '$infile' has unsupported file format!\n";
        exit 1;
    }

    # select columns which contain experiment name
    foreach my $col(keys %header) {
        next unless $col =~ /^RATIO|^INTENSITY\s+[LHM]\s+/;
        my $col_idx = $header{$col};
        foreach my $name(@experiments) {
            next unless $col =~ /\Q$name/; # escape spec. chars.
            push(@{$exp2cidx{$name}}, $col_idx);
        }
        push(@{$exp2cidx{$null}}, $col_idx) unless @experiments;
    }

    # write database table files
    open PGROUP, ">", $pgroup_file or die "Cannot write '$pgroup_file':$!\n";
    open PROT2GRP, ">", $prot2grp_file or die "Cannot write '$prot2grp_file':$!\n";
    open PGROUP_QUANT, ">", $quant_file or die "Cannot write '$quant_file':$!\n";

    # parse infile
    while (<IN>) {
        next if /^#|^protein/i; # skip comment or header line
        chomp;
        my @cols = split/$sep/;
        my ($grp_id,
            $prot_ids,
            $pep_score,
            $id_by_site,
            $is_decoy,
            $is_cont
        );

        $gid++ if @cols;

        # set variables to $null if columns do not exist
        $prot_ids = (defined $header{'PROTEIN IDS'}) ? $cols[$header{'PROTEIN IDS'}] : $null;
        $pep_score = (defined $header{'PEP'}) ? $cols[$header{'PEP'}] : $null;
        $id_by_site = (defined $header{'ONLY IDENTIFIED BY SITE'}) ? $cols[$header{'ONLY IDENTIFIED BY SITE'}] : $null;
        $is_decoy = (defined $header{'REVERSE'}) ? $cols[$header{'REVERSE'}] : $null;
        $is_cont = (defined $header{'CONTAMINANT'}) ? $cols[$header{'CONTAMINANT'}] : $null;

        # post-process column values
        $pep_score = sprintf("%g", $pep_score) if $pep_score =~ /^\d+$/;
        $id_by_site = ($id_by_site eq '+') ? 1 : 0;
        $is_decoy = ($is_decoy eq '+') ? 1 : 0;
        $is_cont = ($is_cont eq '+') ? 1 : 0;

        $grp_id = sprintf("%05d", $gid); # zero-padded group IDs 'xxxxx'

        # Write data files:
        #   PGROUP table data
        print PGROUP
            $grp_id,
            $pep_score,
            $id_by_site,
            $is_decoy,
            $is_cont;

        #   PGROUP_QUANT table data
        while (my ($exp_name, $ref_arr) = each %exp2cidx) {
            foreach my $col_idx(@{$ref_arr}) {
                my $quant_type = $col_names[$col_idx];
                my $quant_value = $cols[$col_idx];
 
                # Post-process column values:
                #   remove experiment name
                #   replace 'NA', 'NaN' or '' by $null
                $quant_type =~ s/\s\Q$exp_name// if @experiments; # escape spec. chars.
                $quant_value = ($quant_value =~ /na/i or not defined $quant_value) ? $null : $quant_value;
                
                print PGROUP_QUANT
                    $grp_id,
                    uc($exp_name),
                    $quant_type,
                    $quant_value;
            }
        }            

        #   PROT2GRP table data:
        #      Exclude any protein accession with CON__ or REV__ prefix.
        #
        foreach my $prot_acc(split(/;\s*/, $prot_ids)) {
            next if $prot_acc =~ /(CON_|REV_)/i;
            print PROT2GRP
                $grp_id,
                $prot_acc;
        }
    }
    close IN;
    close PROT2GRP;
    close PGROUP;
    close PGROUP_QUANT;

    $n_proc_files++;

    if (-z $quant_file) {
        printf(STDERR "Error: No SILAC protein quantitations found in MaxQuant '%s' file. Thus, '%s' table file is empty!\n", $infile, basename($quant_file));
        exit 1;
    }
}
