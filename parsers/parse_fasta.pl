#!/usr/bin/perl
#
# This script reads a sequence library file with UniProtKB-formatted FASTA headers
# (see http://www.uniprot.org/help/fasta-headers) and writes a tab-delimited file.
#
# Example:
#    >sp|A0A183|LCE6A_HUMAN Late cornified envelope protein 6A OS=Homo sapiens GN=LCE6A PE=2 SV=1
#    ...
#
# Output:
#   [acc] [id] [evidence] [gene] [db] [des] [org] [seq]
#   A0A183\tLCE6A_HUMAN\t2\tLCE6A\tUniProtKB/SwissProt\tLate cornified envelope protein 6A\tHomo sapiens\t...
#
#
# Author: Arnold Kuzniar
# Version: 1.0
#

use strict;
use warnings;
use File::Basename;
use File::Spec::Functions;

$, = "\t";
$\ = "\n";

my $infile = shift;
my $outfile = 'PROTEIN.dat';
my $cur_header;
my $prev_header;
my $seq;
my $read = 0;
my $lineno = 0;
my $null = '\N';  # change this depending on RDBMS: in MySQL '\N' becomes NULL

die "$0 [FASTA file]\n" unless $infile;
$outfile = catfile(dirname($infile), $outfile);

open FASTA, $infile or die "Cannot open '$infile' file: $!\n";
open PROTEIN, ">$outfile" or die "Cannot write '$outfile' file: $!\n";

while (<FASTA>) {
    $lineno++;
    if (/^>(.+)/) {
        $cur_header = $1;
        WriteTable() if $read;
    } else {
        $seq .= $_;
        $read = 1; 
    }
    $prev_header = $cur_header;
}

WriteTable();

close PROTEIN;
close FASTA;

sub WriteTable {
    my ($db, $acc, $id, $des, $org, $gene, $evidence, $misc);

    unless ($prev_header) {
        printf(STDERR "Input error: Missing FASTA header after '>' character at line %d.\n", $lineno - 1);
        exit 1;
    }

    $seq =~ s/\s+//g;
    $seq = uc($seq);

    unless ($seq) {
        printf(STDERR "Input error: Missing sequence after FASTA header: >%s.\n", $prev_header);
        exit 1;
    }

    # parse the FASTA header
    #   mandatory fields: db, acc, id, description, organism
    #   optional fields: gene/protein name, protein existence/evidence
    # make use of named capture buffers
    if ($prev_header =~ /^(?<db>\w{2})\|(?<acc>[\w-]+)\|(?<id>\S+)\s+(?<des>.+)\s+OS=(?<misc>.+)/) {
        $db = lc($+{db});
        $acc = $+{acc};
        $id = $+{id};
        $des = $+{des};
        $misc = $+{misc};
        $misc =~ s/SV=\d+//;
        $misc =~ s/PE=(?<evidence>\d+)//;
        $evidence = IFNULL($+{evidence});
        $misc =~ s/GN=(?<gene>.+)//;
        $gene = $+{gene};
        $gene =~ s/\s*$// if $gene;
        $gene = IFNULL($gene);
        $org = $misc;
        $org =~ s/\s*$//;

        print PROTEIN
            $acc,
            $id,
            $evidence,
            $gene,
            $db,
            $des,
            $org,
            $seq;
    } else {
        printf(STDERR "Input error: Unsupported FASTA header format: >%s. Use UniProtKB FASTA headers (see http://www.uniprot.org/help/fasta-headers).\n", $prev_header);
        exit 1;
    }

    $seq = '';
    $read = 0;
}

sub IFNULL {
    my $val = shift;
    my $ret = (not defined($val)) ? $null : $val;
    return $ret;
}
