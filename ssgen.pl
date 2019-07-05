#!/usr/bin/env perl 

# ssgen - static site generator
# Uses Perl version 5.22.1
# Made by Anamitra Ghorui (https://github.com/daujerrene/)

# Copyright 2019 Anamitra Ghorui
# 
# Redistribution and use in source and binary forms, with or without modification, 
# are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice, this 
#    list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright notice, 
#    this list of conditions and the following disclaimer in the documentation 
#    and/or other materials provided with the distribution.
# 
# 3. Neither the name of the copyright holder nor the names of its contributors 
#    may be used to endorse or promote products derived from this software without 
#    specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES 
# INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
# OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, 
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Todo:
#   Implement basedir
#   dir="..."
#

# Usage: 
#   perl ssgen.pl -c [config file] (-V|--verbose)
#   perl ssgen.pl [input file] [output file] [template]
#   
#
#   perl (-v|--version|-h|--help)
#   
# ssgen can be used with a configuration file containing all the files and
# templates that need to be processed to make the site, or can be simply used
# as a program for automaticallly filling up a template with a given source
# document/file.
# ssgen can also automatically create directory listings of a certain directory,
# either by directly invoking a command or from a config file.
# 
# Please see example.cfg for an example configuration file.

use strict;
use warnings;
use Data::Dumper;
use File::Copy;
use POSIX;

# Default Variables


# Cfg File Grammmar
my $sg_kvrgx = '^\s*(\w+)=\"([\w\\\.\/]+)\"\s*;?$'; # Key-Value Pairs
my $sg_blrgx = '^\s*(\"?[\w\\\.\/]+\"?)\s*:$'; # Block start
my $sg_listrgx = '^\s*[\"]?([\w\\\.\/]+)[\"]?\s*=>\s*[\"]?([\w\\\.\/]+)[\"]?\s*$'; # Block element
my $sg_listrgx1 = '^\s*[\"]?([\w\\\.\/])[\"]?\s*$'; # Block element (alternative)
my $sg_comrgx = '^\s*\#.*$'; # Comments
my $sg_wsrgx = '^\s*$'; # Whitespace

# Source File Grammar
my $sg_datargx = '^\#\#([A-Za-z]+):$'; # Normal data identifier (can be used for <body> etc.)
my $sg_datargx_d = '^\#\#\!$'; # Normal data identifier delimiter
my $sg_inlinergx = '^\#\#([A-Za-z]+)=(.*)$'; # Inline data identifier (can be used for <title>, <span> etc.)

# Template File Grammar
my $sg_srgx = '\{\{([\_\w\-]+)\}\}'; # Expression to be substituted

# Informational/"Internal" Variables
my $sg_i_version = "0.1.0 NotUsable";

my $sg_i_helpmsg = <<"!!ESTR";
ssgen - Static Site Generation Tool
Version: $sg_i_version

Usage:
\tperl ssgen.pl (-c [config file]|--version|--verbose|-v|-h|--help)
\tperl ssgen.pl [input file] [output file] [template]

Options:
\t-c [config file] : Run ssgen with a configuration file.
\t-V, --verbose : Display verbose output.
\t-v, --version : Display version.
\t-h, --help    : Display this message
!!ESTR

my $sg_i_verbose = 0;

my @sg_resdir =
(
    "",
    "/usr/local/share/ssgen"
);

my %sg_vars = # Key-Value Variables
(
    "root" => "./www/",
    "src" => "./"
);

my %sg_mods = # Modifiers/"Special" functions
(
    "copy" => 1,
    "findex" => 1
);

# Variables for modifiers

my $sgm_trf = "<tr><td><a href=\"%s\">%s</a>&nbsp;&nbsp;</td><td>%s&nbsp;&nbsp;</td><td>%d&nbsp;&nbsp;</td></tr>"; # Table row (<tr>) format\
my $sgm_fdirindex = "t_dirindex.xhtml1.0t.html"; # Default directory index template

# Helper functions

sub sg_Alert
{
    print @_ if ($sg_i_verbose);
}

sub sg_LoadFile # Load resource from predefined resource directories (see sg_resdir)
{
    my ($mode, $path) = @_;
    my $fh;
    for(my $i = 0;($i < scalar(@sg_resdir)); ++$i)
    {
        return $fh if(open($fh, $mode, $sg_resdir[$i] . $path));
    }
    die("Error: could not load " . $path . " from predefined paths.\n") unless (defined $fh);
}

sub sg_Dircmp
{
    if(-d $sg_vars{root} . $a->{name})
    {
        return -1;
    }
    elsif(-d $sg_vars{root} . $b->{name})
    {
        return 1;
    }
    else
    {
        return $a cmp $b;
    }
    
}

# Generators

sub sg_GTemplate
{
    my ($tfileh, $infileh, $table, $symbols, $outfileh) = @_;
    my $tline;
    my $sline;
    
    while($tline = <$tfileh>)
    {
        if($tline =~ qr/$sg_srgx/)
        {
            if(exists $symbols->{data}->{$1})
            {
                seek($infileh, $table->[$symbols->{data}->{$1}]->{bpos}, 0);
                print $outfileh substr($tline, 0, $-[0]);
                for(my $i = 1; $i < ( $table->[$symbols->{data}->{$1} + 1]->{blpos} 
                                    - $table->[$symbols->{data}->{$1}]->{blpos}); 
                    $i++)
                {
                    $sline = <$infileh>;
                    print $outfileh $sline;
                }
                print $outfileh substr($tline, $+[0]);
            }
            elsif(exists $symbols->{inline}->{$1})
            {
                print $outfileh substr($tline, 0, $-[0]);
                print $outfileh $table->[$symbols->{inline}->{$1}]->{data};
                print $outfileh substr($tline, $+[0]);
            }
            else 
            {
                die("Error: Key $1 does not exist in input file.");
            }
        }
        else
        {
            print $outfileh $tline;
        }
    }
    
    seek($tfileh, 0, SEEK_SET);
}

sub sg_GCopy
{
    my ($src, $dest) = @_;
    copy($src, $dest) or die("Error: could not copy $src to $dest\n");
}

sub sg_GFindex
{
    my ($dirn, $dirh, $outfileh, $tfileh) = @_;
    my $tline;
    
    my @si;
    my $dirl;
    
    for(my $i = 0; $tline = <$tfileh>; ++$i)
    {
        if($tline =~ qr/$sg_srgx/)
        {
            if($1 eq "SG_FILEPATH")
            {
                print $outfileh substr($tline, 0, $-[0]);
                print $outfileh $dirn;
                print $outfileh substr($tline, $+[0]);
            }
            elsif($1 eq "SG_ENTRIES")
            {
                while(readdir($dirh))
                {
                    if($_ eq "." || $_ eq "index.html")
                    {
                        next;
                    }
                    elsif(-d $sg_vars{root} . $dirn . $_)
                    {
                        $dirl->[0]->[@{$dirl->[0]}] = $_ . "/";
                    }
                    else
                    {
                        $dirl->[1]->[@{$dirl->[1]}] = $_;
                    }
                }
                foreach my $i (@$dirl)
                {
                   @$i = sort {$a cmp $b} @$i;
                }
                foreach my $i (@$dirl)
                {
                    foreach my $j (@$i)
                    {
                        @si = stat($sg_vars{root} . $j);
                        printf $outfileh ($sgm_trf, $j, $j, strftime("%F, %T", gmtime($si[9])) . " GMT", $si[7]);
                    }
                }
            }
            elsif($1 eq "SG_INFOMSG")
            {
                printf $outfileh substr($tline, 0, $-[0]);
                printf $outfileh "ssgen v" . $sg_i_version;
                printf $outfileh substr($tline, $+[0]);
            }
            else
            {
                die("Error at line $i: Key \'$1\' is not valid\n");
            }
        }
        else
        {
            print $outfileh $tline;
        }
    }
    
    seek($tfileh, 0, SEEK_SET);
}

#TODO: Possibly rework function
sub sg_ParseSrc
{
    my ($fsrch,
    $table,  # Table of source block line and character positions
    $symbols # Table consisting of respective symbols denoting blocks
    ) = @_;
    
    my $k = 1;
    my $line;

    for($k = 1; $line = <$fsrch>; $k++)
    {
        if ($line =~ qr/$sg_datargx/)
        {
            $table->[@{$table}]->{bpos} = tell($fsrch);
            $table->[@{$table} - 1]->{blpos} = $k;
            $symbols->{data}->{$1} = @{$table} - 1;
        }
        elsif($line =~ qr/$sg_inlinergx/)
        {
            $table->[@{$table}]->{data} = $2;
            $table->[@{$table} - 1]->{blpos} = $k;
            $symbols->{inline}->{$1} = @{$table} - 1;
        }
        elsif($line =~ qr/$sg_datargx_d/)
        {
            $table->[@{$table}]->{blpos} = $k;
        }
    }
    
    $table->[@{$table}]->{blpos} = $k;
    
    seek($fsrch, 0, 0);
}

sub sg_ParseCfg
{
    my ($fcfgh) = @_;
    
    my $cb = "";    # Current Block
    my $tmpl = 0;   # Is current block a template block?
    my %ftable;     # File Table
    my $line;
    
    
    for(my $i = 1; $line = <$fcfgh>; ++$i)
    {
        if($line =~ qr/$sg_kvrgx/)
        {
            if(exists $sg_vars{$1})
            {
                $sg_vars{$1} = $2;
            } 
            else 
            {
                die("Error at line $i: Key \'$1\' is not valid\n");
            }
        }
        elsif($line =~ qr/$sg_blrgx/)
        {
            $cb = $1;
            if($1 =~ m/^"(.+)"$/)
            {
               $tmpl = 1;
               $cb = $1;
            }
            else
            {
                if(exists $sg_mods{$cb})
                {
                    $tmpl = 0;
                }
                else
                {
                    die("Error at line $i: Illegal block name:\n$line\n");
                }
            }
        }
        elsif($line =~ qr/$sg_listrgx/)
        {
            if($cb eq "")
            {
                die("Error at line $i: Stray list item:\n$line\n");
            }
            
            if($tmpl)
            {
                $ftable{temp}{$cb}[@{$ftable{temp}{$cb}}] = [($1, $2)];
            }
            else
            {
                $ftable{$cb}[@{$ftable{$cb}}] = [($1, $2)];
            }
        }
        elsif($line =~ qr/$sg_listrgx1/)
        {
            if($tmpl)
            {
                 die("Error at line $i: Incorrect Syntax:\n$line\n");
            }
            else
            {
                $ftable{$cb}[@{$ftable{$cb}}] = [$1];
            }
        }
        elsif( $line =~ qr/$sg_wsrgx/ or $line =~ qr/$sg_comrgx/)
        {
            next;
        }
        else
        {
            die("Error at line $i: Incorrect syntax:\n$line\n");
        }
    }
    
    return %ftable;
}

sub sg_Generate
{
    my (%ftable) = @_;
    # Operative File handles
    my $infileh;
    my $outfileh;
    my $tfileh;
    
    # Tables:
    my %symbols;
    my @stable;
    
    # Open Template
    # Paths are prefixed by the root path or the src path.
    
    foreach my $i (keys %{ $ftable{temp} })
    {
        sg_Alert("Template: " . $i . "\n");
        open($tfileh, "<", $sg_vars{src} . "/" . $i) or die("Error: Could not open " . $i . "\n");
        

        # Open Source and dest.
        foreach my $j ( @{ $ftable{temp}{$i} })
        {
            sg_Alert("\t" . $j->[0] .  " => " . $j->[1] . "\n");
            open($infileh, "<", $sg_vars{src} . "/" . $j->[0]) or die("Error: Could not open " . $j->[0] . "\n");
            open($outfileh, ">",$sg_vars{root} . "/" . $j->[1]) or die("Error: Could not open " . $j->[1] . "\n");
            
            # Ready the files
            sg_ParseSrc($infileh, \@stable, \%symbols);
            sg_GTemplate($tfileh, $infileh, \@stable, \%symbols, $outfileh);
            close($infileh);
            close($outfileh);
        }
        
        foreach my $i ( @{ $ftable{copy} })
        {
            if(undef $i->[1])
            {
                $i->[1] = $i->[0];
            }
            sg_GCopy($sg_vars{root} . $i->[0], $sg_vars{root} . $i->[1]);
        }
        
        $tfileh = sg_LoadFile("<", $sgm_fdirindex);
        
        foreach my $i ( @{ $ftable{findex} })
        {
            my $outfilen;
            my $dirh;
            
            sg_Alert("Dir: " . $i->[0] . "\n");
            opendir($dirh, $sg_vars{root} . $i->[0]) or die("Error: Could not open " . $i->[0] . "\n");
            if(exists $i->[1])
            {
                $outfilen = $i->[1];
            }
            else 
            {
                $outfilen = $i->[0] . "/index.html";
            }
            
            open($outfileh, ">", $sg_vars{root} . $outfilen) or die("Error: Could not open " . $outfilen . "\n");
            sg_GFindex($i->[0], $dirh, $outfileh, $tfileh);
            close($dirh);
            close($outfileh);
        }
        
        close($tfileh);
    }
}

sub sg_Main {
    
    my $phelp = 1;
    my $fcfgh;
    my $nfcfg;
    my %ftable;
    
    for(my $i = 0; $i <= $#ARGV; ++$i)
    {
        $_ = $ARGV[$i];
        
        if(/-V/ || /--version/)
        {
            print("SSGen Version " . $sg_i_version . "\n");
            exit(0);
        }
        elsif(/-h/ || /--help/)
        {
            print($sg_i_helpmsg);
            exit(0);
        }
        elsif(/-c/)
        {
            open($fcfgh, "<", $ARGV[$i + 1]) or
            die("Error: Could not open " . $ARGV[$i + 1] . "\n");
            $nfcfg = \$ARGV[$i + 1];
            $phelp = 0;
            ++$i;
            next;
        }
        elsif(/-v/ || /--verbose/)
        {
            $sg_i_verbose = 1;
        }
        else
        {
            print("Error: Unknown flag " . $ARGV[$i] . "\n");
            print($sg_i_helpmsg);
            exit(1);
        }
    }
    
    print($sg_i_helpmsg) and exit(0) if($phelp);
    
    sg_Alert("Parsing: " . $$nfcfg . "\n");
    %ftable = sg_ParseCfg($fcfgh);
    close($fcfgh);
    die("Error: Nothing to process.\n") if(keys %ftable <= 0);
    
    #Debug
    sg_Generate(%ftable);
    sg_Alert("Done.\n");
}

sg_Main();
