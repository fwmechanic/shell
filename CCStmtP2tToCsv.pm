package CCStmtP2tToCsv;

# seeking to convert a credit card PDF statement content to CSV or similar
# I stumbled across the fact that (Windows) git-bash includes pdftotext, and
# that pdftotext's "simple" mode does a very fine job of extracting what I need
# (in the case perhaps ONLY of this particular CC company's PDF statement)!
# What's left is to slice and dice the "simple" output.  It's only a bit hacky.

# client programs of this library:
# %~dp0/citi_stmt_to_csv-table
# %~dp0/chase_stmt_to_csv-simple

# run on output of `pdftotext -simple/-table CreditCardStatement.pdf`

use strict;
use warnings;
use Carp 'croak';
use Data::Dumper;
use Getopt::Std ();

$Data::Dumper::Sortkeys = 1;

sub getopts {
   my %opts;
   Getopt::Std::getopts('vh', \%opts);
   if( $opts{h} ) {
      my($scriptname, $scriptdirs, $scriptsuffix) = File::Basename::fileparse($0);
      print STDERR <<"EOT";
$scriptname: convert Credit Card PDF statement to structured text (CSV)
usage: $scriptname [-h] [-v] [inputfilename]
  -h   this help
  -v   verbose
EOT
      die "abend\n"
      }
   return \%opts;
   }

sub rpmdamtcapt { '\s+([-+]?\$?[\d,]*\.\d{2})\b'; }

sub tocents { my ($dcstr) = @_;  # convert currency to cents to avoid inexact floating point ops
   $dcstr =~ s/[,\$]//g;
   my ($sign,$dol,$cents) = $dcstr =~ /^([-+]?)(\d*)\.(\d{2})$/;
   $cents = ((($dol || 0) * 100) + $cents);
   $cents = 0 - $cents if $sign eq '-';
   return $cents;
   };

my $maxdollarMagnitude = 5;  # we don't expect to be dealing with amounts over $99999.99 (mark my words!)
sub cents_to_dc_pretty { my ($cents,$dw) = @_; sprintf( "%*d.%02d", $dw // $maxdollarMagnitude, $cents / 100, $cents % 100 ); }
sub cents_to_dc        { my ($cents) = @_; sprintf  "%d.%02d", $cents / 100, $cents % 100; }

sub _genkey { my $self = shift; my $aref = shift;
   my $rv = join( '::', @$aref );
   $self->{maxkeylen} = length($rv) unless exists $self->{maxkeylen} && $self->{maxkeylen} > length($rv);
   return ($rv, sprintf( '%-*s', $self->{maxkeylen}, $rv ));
   }

sub _cross_chk_totals { my ($self,$stmtTotal,$accumdTxns,$anno) = @_;
   $anno = sprintf '%-*s', $self->{maxkeylen}, $anno;
   if( $stmtTotal != $accumdTxns ) {
      printf "**************************************************************************************\n";
      printf "cross-check $anno: stmtTotal (%s) != accumdTxns (%s) DIFFER by %s !!!\n", cents_to_dc_pretty($stmtTotal), cents_to_dc_pretty($accumdTxns), cents_to_dc_pretty($stmtTotal - $accumdTxns);
      printf "**************************************************************************************\n";
      return 1;
      }
   else {
      printf "cross-check $anno: stmtTotal (%s) == accumdTxns (%s) same\n", cents_to_dc_pretty($stmtTotal), cents_to_dc_pretty($accumdTxns);
      return 0;
      }
   }

sub _updt_section_hdr_re { my $self = shift;
   my $reraw = '(?!)';  # never matches  https://stackoverflow.com/a/4589566
      $reraw = '^\s*(' . join( '|', sort keys %{$self->{section_parsers}} ) . ')\b' if %{$self->{section_parsers}};
   print "updt_section_hdr_re = $reraw\n" if $self->{opts}{v};
   $self->{section_hdr_re} = qr{$reraw};
   }
sub _found_section_hdr { my $self = shift; my ($lphdr) = @_;
   my ($lpnorm) = $lphdr =~ s!\s+! !gr;
   my ($lprex ) = $lphdr =~ s!\s+!\\s+!gr;
   croak "$lphdr missing!\n" unless exists $self->{section_parsers}{ $lprex };
   print "lineparser = $lpnorm\n" ; # if $self->{opts}{v};
   my $lpsub = delete( $self->{section_parsers}{ $lprex } );
   $self->_updt_section_hdr_re();
   push @{$self->{sections_seen}}, $lpnorm;
   return $lpsub;
   }
my $_norm_hr_keys = sub { my ($hr) = @_;
   my %tochg;
   for my $ok ( keys %$hr ) {
      my $nk = $ok =~ s!\s+!\\s+!gr;
      $tochg{$ok} = $nk unless $ok eq $nk;
      }
   for my $ok ( keys %tochg ) {
      $hr->{$tochg{$ok}} = delete $hr->{$ok};
      }
   };
sub add_section_hdr { my $self = shift; my ($hdr,$coderef) = @_;
   print "add_section_hdr $hdr\n" ; # if $self->{opts}{v};
   $hdr =~ s!\s+!\\s+!g;
   $self->{section_parsers}{ $hdr } = $coderef;
   $self->_updt_section_hdr_re();
   }
sub rmv_section_hdr { my $self = shift; my ($lprex) = @_;
   print "rmv_section_hdr $lprex\n" ; # if $self->{opts}{v};
   $self->_updt_section_hdr_re() if delete( $self->{section_parsers}{ $lprex } );
   }
sub _section_parsers_report { my $self = shift;
   printf "\nsection_parsers\n  unmatched: %d\n", scalar keys %{$self->{section_parsers}};
   for my $lprex ( sort keys %{$self->{section_parsers}} ) {
      print "    ", $lprex =~ s!\Q\s+! !gr, "\n";
      }
   printf "  matched: %d\n    sorted: %s\n    order seen:\n"
      , scalar @{$self->{sections_seen}}
      , join('|', sort @{$self->{sections_seen}});
   print "      ", $_, "\n" for @{$self->{sections_seen}};
   }
sub add_txn { my $self = shift; my ($aref,$postdate,$cents,$descr,$ctx,$src) = @_;
   my $txtype = $aref->[0];  # semi-hack
   my $patched = ' ';
   if( defined $self->{patchDesc}{$txtype}{$descr} ) {
      delete( $self->{patchDescMiss}{"$txtype,$descr"} );
      $descr = $self->{patchDesc}{$txtype}{$descr};
      $patched = '!';
      }
   my ($txcat,$dispcat) = $self->_genkey( $aref );
   my %txn = ( txcat=>$txcat, date=>$postdate, cents=>$cents, description=>$descr );
   $txn{context} = $ctx if defined $ctx;
   $txn{srcdoc}  = $src if defined $src;
   push @{$self->{txnByDate}{$txtype}{$postdate}}, \%txn;
   # print Data::Dumper->Dump([ $self->{txnTotal$selfKey} ], [ 'before '.txnTotal ]), "\n";
   for( my $ix = 0; $ix < scalar @$aref; ++$ix ) {
      my $key = join('::', @$aref[0..$ix]);  # print "  $key += $cents", "\n" Data::Dumper->Dump([ $self->{txnTotal} ], [qw(hr)]), "\n";
      $self->{txnTotal}{$key} += $cents;
      }
   # print Data::Dumper->Dump([ $self->{txnTotal} ], [ 'after  '.txnTotal ]), "\n";
   printf "add_txn %s: %s %s %s%s\n", $dispcat, $postdate, cents_to_dc_pretty($cents), $patched, $descr;
   }

sub _patch_txn_desc { my $self = shift; my($txtype, $from, $to) = @_;
   print "_patch_txn_desc $txtype, $from, $to\n";
   $self->{patchDesc}{$txtype}{$from} = $to;
   $self->{patchDescMiss}{"$txtype,$from"} = 1;
   }

sub set_total { my $self = shift; my ($aref,$dcstr) = @_; my $cents = tocents($dcstr);
   my ($key) = $self->_genkey( $aref );
   print "set_total $key = ", cents_to_dc($cents), "\n" ; # if $self->{opts}{v};
   die "multiple definitions of stmtTotal[$key]\n" if exists $self->{stmtTotal}{$key};
   $self->{stmtTotal}{$key} = $cents;
   # print Data::Dumper->Dump([ $self->{stmtTotal} ], [ 'stmtTotal.after' ]), "\n";
   }
sub add_total { my $self = shift; my ($aref,$dcstr) = @_; my $cents = tocents($dcstr);  # some totals summed from multiple sources
   my ($key) = $self->_genkey( $aref );
   print "add_total $key = ", cents_to_dc($cents), "\n" ; # if $self->{opts}{v};
   $self->{stmtTotal}{$key} += $cents;
   # print Data::Dumper->Dump([ $self->{stmtTotal} ], [ 'stmtTotal.after' ]), "\n";
   }

sub set_stmtOpenCloseDates { my $self = shift; # my ($closeDate, $yrMin, $yrMax) = @_;
   croak "multiple calls to set_stmtOpenCloseDates\n" if exists $self->{closeDate};
   my $yrMin = $1 + 2000;                 print "yrMin $yrMin\n";
   my $yrMax = $4 + 2000 if $1 ne $4;     print "yrMax $yrMax\n" if $yrMax;
   my $closeDate = $4 + 2000 . "-$2-$3";  print "closeDate $closeDate\n";
   $self->{closeDate} = $closeDate;
   $self->{yrMin} = $yrMin;
   $self->{yrMax} = $yrMax;
   }

sub parse_new_txn { my $self = shift; my ($retxn,$aref) = @_;
   $self->{yrMin} or die "yrMin not defined prior to txn processing\n";
   if( m"$retxn" ) {
      # print "parse_new_txn $1, $2, $3\n";
      my ($txpostdt,$txdesc,$txcents) = ($1, $2, tocents($3));
      # print "parse_new_txn $txpostdt, $txdesc, $txcents\n";
      $txpostdt =~ s!/!-!g;  # ISO8660 sep
      $txpostdt = (($self->{yrMax} && $txpostdt =~ m"^01") ? $self->{yrMax} : $self->{yrMin}) . "-$txpostdt";  # prepend year
      $txdesc =~ s!\s+! !g;
      $self->add_txn( $aref, $txpostdt, $txcents, $txdesc );
      }
   }

my $_byDateToList = sub { my ($self,$txtype) = @_;  # private manually called helper method
   my $bdthref = $self->{txnByDate}{$txtype};
   my ($srcFnm, $acctId, $closeDt) = @$self{ qw( p2tfnm acctId closeDate ) };  # efficiency (hash slice)
   my @rslt;
   for my $dt ( sort keys %$bdthref ) {
      for( my $ix=0 ; $ix < scalar @{$bdthref->{$dt}} ; ++$ix ) {
         my $hr = $bdthref->{$dt}[$ix];
         $hr->{dtsnum}   = $ix;  # modify source!
         $hr->{dc}       = cents_to_dc( $hr->{cents} );
         $hr->{srcdoc} ||= $srcFnm;  # modify source (denormalize)
         $hr->{acctId}   = $acctId;  # modify source (denormalize)
         $hr->{closeDt}  = $closeDt; # modify source (denormalize)
         $hr->{stmtId}   = $acctId .'+closeDt='. $closeDt; # modify source (denormalize)
         push @rslt, $hr;
         }
      }
   return \@rslt;
   };

my @allcsv;
sub _rdAddlTxns { my $self = shift; my ($ifnx, $ifx) = @_;
   print "ifx $ifx\n\n";
   my ($ifxsuffix) = $ifx =~ m"[^\-]+(\-[^\-]+)$";
 # my ($ifxprefix,$ifxsuffix) = split( /-/, $ifx, 2 );
   my $src  = 'addltxns';
      $src .= $ifxsuffix if $ifxsuffix;
   my $addltxnfnm = $ifnx . $src;
   print "addltxnfnm $addltxnfnm\n\n";
   if( -e $addltxnfnm ) {
      print "addltxnfnm $addltxnfnm\n\n";
      my $rdesc = '\w.*\w';
      my $rentry = "($rdesc)".':\s+(\d{4}\-\d{2}\-\d{2})\s+(\d+)\s+'."($rdesc)";
      open my $ifh, '<', $addltxnfnm or die "abend cannot open $addltxnfnm for reading: $!\n";
      while( <$ifh> ) {
         chomp;
         if( m"\S" ) {
            if( m"^(?:add:\s+)?$rentry" ) {
               my ($holder,$dt,$txcents,$desc) = ($1, $2, $3, $4);
               $self->add_txn( ['charge', $holder], $dt, $txcents, $desc, $holder, $src );
               }
            elsif( m"^desc:\s+($rdesc)\s*\|\s*($rdesc)" ) {
               $self->_patch_txn_desc( 'charge', $1, $2 );
               }
            else { die "bad format in $addltxnfnm: $_\n"; }
            }
         }
      print "\n";
      }
   }
sub process_stmt_p2t { my($p2tfnm,$spref,$init_sp_key,$ar_export_txntypes,$opts) = @_;
   print "p2tfnm $p2tfnm\n\n";
   -e $p2tfnm or croak "$p2tfnm is not a file\n";
   # does not produce desired results:
   # my($ifnmname, $ifnmdirs, $ifnmsuffix) = fileparse($ifnm);
   # print "$ifnm, $ifnmname, $ifnmdirs, $ifnmsuffix\n";
   my ($ifnx,$ifx) = $p2tfnm =~ m"(.+\.)([^\.]+)$";
   $_norm_hr_keys->( $spref );
   my $self = {
      p2tfnm => $p2tfnm,
      section_parsers => $spref,
      sections_seen => [],
      txnTotal => {},
      stmtTotal => {},
      opts => $opts,
      };
   bless $self;
   require './AccountId.pl' or die;
   $self->{acctId} = &AccountId;  # print "acctId $self->{acctId}\n";
   $self->_rdAddlTxns( $ifnx, $ifx );
   print "$p2tfnm\n\n";
   {
   open my $ifh, '<', $p2tfnm or croak "abend cannot open $p2tfnm for reading: $!\n";
   my $lineparser = $self->_found_section_hdr( $init_sp_key );
   while( <$ifh> ) { chomp;  # print "new line = $_\n";
      if( m"$self->{section_hdr_re}" ) {
         $lineparser = $self->_found_section_hdr( $1 );
         }
      elsif( $lineparser ) {
         $lineparser->( $self );
         }
      }
   }

   # print Data::Dumper->Dump([$self->{stmtTotal},$self->{txnTotal}], [qw(stmtTotal txnTotal)]), "\n";

   { my ($failCt,%xchkd) = (0);  print "\ncross-checking\n\n";
   for my $catkey ( sort keys %{$self->{stmtTotal}} ) {
      $xchkd{$catkey} = 1;
      $failCt += $self->_cross_chk_totals( $self->{stmtTotal}{$catkey}, $self->{txnTotal}{$catkey} || 0, $catkey );
      }
   for my $catkey ( sort keys %{$self->{txnTotal}} ) {
      $failCt += $self->_cross_chk_totals( 0, $self->{txnTotal}{$catkey}, $catkey ) unless exists $xchkd{$catkey};
      }
   die "$failCt failed cross checks\n" if $failCt > 0;
   }

   if( exists( $self->{patchDescMiss} ) && %{$self->{patchDescMiss}} ) {
      print "desc patches were provided which were not applied:\n";
      print "  $_\n" for ( sort keys %{$self->{patchDescMiss}} );
      die "\n";
      }

   $self->_section_parsers_report();

   for my $txtype ( sort keys %{$self->{txnByDate}} ) {  print "$txtype\n";
      $self->{txnsByType}{$txtype} = $_byDateToList->( $self, $txtype );
      }

   if( 0 ) {  # various debug variants
      # print Data::Dumper->Dump([$self->{txnByDate}, $self->{txnsByType}], [qw(txnByDate txnsByType)]);
        print Data::Dumper->Dump([$self->{txnByDate} ], [qw(txnByDate )]);
        print Data::Dumper->Dump([$self->{txnsByType}], [qw(txnsByType)]);
      }

   { my $ofnm = $ifnx . 'DDump';
   open my $ofh, '>', $ofnm or croak "abend cannot open $ofnm for writing: $!\n";
   print $ofh Data::Dumper->Dump([$self->{txnsByType}], [qw(txnsByType)]);
   }
   my @csvLines;
   { my $ofnm = $ifnx . 'csv';
   open my $ofh, '>', $ofnm or croak "abend cannot open $ofnm for writing: $!\n";
   my @hdr = qw( date dc description stmtId );
 # print $ofh join( ',', map { '"'.$_.'"' } @hdr ), "\n";  # CSV file header line (can be omitted)
   for my $txntype ( sort @{$ar_export_txntypes} ) {
      for my $txhref ( @{$self->{txnsByType}{$txntype}} ) {
         my $csvline = join( ',', map { '"'.$_.'"' } @{$txhref}{@hdr} );  # hash slice
         push @csvLines, $csvline;
         print $ofh $csvline, "\n";
         }
      }
   }
   print "\ndone with $p2tfnm\n\n";
   push @allcsv, @csvLines;
   }

sub write_all_csv {
   my $ofnm = 'all.csv';
   open my $ofh, '>', $ofnm or die "abend cannot open $ofnm for writing: $!\n";
   print $ofh join( "\n", @allcsv ), "\n";  # sorting @allcsv here can change order of same-day transactions based on their dollar amount (which is undesirable)
   }

1;
