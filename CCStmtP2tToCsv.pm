package CCStmtP2tToCsv;

# seeking to convert a credit card PDF statement content to CSV or similar
# I stumbled across the fact that git-bash includes pdftotext, and
# that pdftotext's "simple" mode does a very fine job of extracting what I need
# (in the case perhaps ONLY of this particular CC company's PDF statement)!
# What's left is to slice and dice the "simple" output.  It's only a bit hacky.

# run on output of `pdftotext -simple CreditCardStatement.pdf`

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

sub tocents { my ($dcstr) = @_;  # convert currency to cents to avoid inexact floating point ops; any leading sign or $ shall have been stripped.
   $dcstr =~ s/[,]//g;
   my ($dol, $cents) = $dcstr =~ /^(\d*)\.(\d{2})$/;
   return ((($dol || 0) * 100) + $cents);
   }

sub cents_to_dc_pretty { my ($cents) = @_; sprintf "%5d.%02d", $cents / 100, $cents % 100; }
my $cents_to_dc = sub  { my ($cents) = @_; sprintf  "%d.%02d", $cents / 100, $cents % 100; };

sub showtxn { my ($holder,$dt,$txcents,$desc) = @_;
   printf "%-17s: %s %s %s\n", $holder, $dt, cents_to_dc_pretty($txcents), $desc;
   }

sub cross_chk_totals { my ($stmtTotal,$accumdTxns,$anno) = @_;
   $anno = sprintf "%-26s", $anno;
   if( $stmtTotal != $accumdTxns ) {
      printf "**************************************************************************************\n";
      printf "cross-check $anno: stmtTotal (%s) != accumdTxns (%s) DIFFER by %s !!!\n", cents_to_dc_pretty($stmtTotal), cents_to_dc_pretty($accumdTxns), cents_to_dc_pretty($stmtTotal - $accumdTxns);
      printf "**************************************************************************************\n";
      exit(1);
      }
   else {
      printf "cross-check $anno: stmtTotal (%s) == accumdTxns (%s) same\n", cents_to_dc_pretty($stmtTotal), cents_to_dc_pretty($accumdTxns);
      }
   }



sub _updt_section_hdr_re { my $self = shift;  # private method
   my $reraw = '(?!)';  # never matches  https://stackoverflow.com/a/4589566
      $reraw = '^\s*(' . join( '|', sort keys %{$self->{section_parsers}} ) . ')\b' if %{$self->{section_parsers}};
   print "updt_section_hdr_re = $reraw\n" if $self->{opts}{v};
   $self->{section_hdr_re} = qr{$reraw};
   }
sub _found_section_hdr { my $self = shift; my ($lphdr) = @_;
   my ($lpnorm) = $lphdr =~ s!\s+! !gr;
   my ($lprex ) = $lphdr =~ s!\s+!\\s+!gr;
   croak "$lphdr missing!\n" unless exists $self->{section_parsers}{ $lprex };
   print "lineparser = $lpnorm\n" if $self->{opts}{v};
   my $lpsub = delete( $self->{section_parsers}{ $lprex } );
   $self->_updt_section_hdr_re();
   push @{$self->{sections_seen}}, $lpnorm;
   return $lpsub;
   }
sub add_section_hdr { my $self = shift; my ($hdr,$coderef) = @_;
   $hdr =~ s!\s+!\\s+!g;
   $self->{section_parsers}{ $hdr } = $coderef;
   $self->_updt_section_hdr_re();
   }
sub _section_parsers_report { my $self = shift;
   printf "\n%d section_parsers used:\n", scalar @{$self->{sections_seen}};
   for my $lpnorm ( sort @{$self->{sections_seen}} ) {
      print "   ", $lpnorm, "\n";
      }
   printf "\n%d unmatched section_parsers:\n", scalar keys %{$self->{section_parsers}};
   for my $lprex ( sort keys %{$self->{section_parsers}} ) {
      print "   ", $lprex =~ s!\Q\s+! !gr, "\n";
      }
   }
sub add_txn { my $self = shift; my ($txtype,$totalnm,$postdate,$cents,$descr,$ctx,$src) = @_;
   my %txn = ( txtype=>$txtype, totalnm=>$totalnm, date=>$postdate, cents=>$cents, description=>$descr );
   $txn{context} = $ctx if defined $ctx;
   $txn{srcdoc}  = $src if defined $src;
   push @{$self->{txnByDate}{$txtype}{$postdate}}, \%txn;
   push @{$self->{txnByTotal}{$totalnm}}, \%txn;
   $self->{totalnmToTxtype}{$totalnm} ||= $txtype;
   }

sub set_total { my $self = shift; my ($txtype,$cents) = @_;
   croak "multiple definitions of txnTypeTotal[$txtype]\n" if exists $self->{txnTypeTotal}{$txtype};
   $self->{txnTypeTotal}{$txtype} = $cents;
   printf "total $txtype = %s\n", cents_to_dc_pretty($cents);
   }

sub set_stmtCloseDate { my $self = shift; my ($closeDate, $yrMin, $yrMax) = @_;
   croak "multiple calls to set_stmtId\n" if exists $self->{closeDate};
   $self->{closeDate} = $closeDate;
   $self->{yrMin} = $yrMin;
   $self->{yrMax} = $yrMax;
   }
sub set_stmtOpenCloseDates { my $self = shift; # my ($closeDate, $yrMin, $yrMax) = @_;
   my $yrMin = $1 + 2000;                 print "yrMin $yrMin\n";
   my $yrMax = $4 + 2000 if $1 ne $4;     print "yrMax $yrMax\n" if $yrMax;
   my $closeDate = $4 + 2000 . "-$2-$3";  print "closeDate $closeDate\n";
   $self->set_stmtCloseDate( $closeDate, $yrMin, $yrMax );
   }

sub parse_new_txn { my ($self,$retxn,$txntype,$totalnm) = @_;
   $self->{yrMin} or die "yrMin not defined prior to txn processing\n";
   if( m"$retxn" ) {
      $totalnm ||= $txntype;
      my ($txpostdt,$txdesc,$sign,$txcents) = ($1, $2, $3, tocents($4));
      $txpostdt =~ s!/!-!g;  # ISO8660 sep
      $txpostdt = (($self->{yrMax} && $txpostdt =~ m"^01") ? $self->{yrMax} : $self->{yrMin}) . "-$txpostdt";  # prepend year
      $txcents = 0 - $txcents if $sign eq '-';
      $txdesc =~ s!\s\s+! # !g;
      showtxn( $totalnm, $txpostdt, $txcents, $txdesc );
      $self->add_txn( $txntype, $totalnm, $txpostdt, $txcents, $txdesc );
      }
   }

my $_byDateToList = sub { my ($self,$type) = @_;  # private manually called helper method
   my $bdthref = $self->{txnByDate}{$type};
   my ($srcFnm, $acctId, $closeDt) = ($self->{p2tfnm},$self->{acctId},$self->{closeDate});  # efficiency
   my @rslt;
   for my $dt ( sort keys %$bdthref ) {
      for( my $ix=0 ; $ix < scalar @{$bdthref->{$dt}} ; ++$ix ) {
         $bdthref->{$dt}[$ix]{dtsnum}   = $ix;  # modify source!
         $bdthref->{$dt}[$ix]{dc} = $cents_to_dc->($bdthref->{$dt}[$ix]{cents});
         $bdthref->{$dt}[$ix]{srcdoc} ||= $srcFnm;  # modify source (denormalize)
         $bdthref->{$dt}[$ix]{acctId}   = $acctId;  # modify source (denormalize)
         $bdthref->{$dt}[$ix]{closeDt}  = $closeDt; # modify source (denormalize)
         $bdthref->{$dt}[$ix]{stmtId}   = $acctId .'+closedt='. $closeDt; # modify source (denormalize)
         push @rslt, $bdthref->{$dt}[$ix];
         }
      }
   return \@rslt;
   };

sub _rdAddlTxns { my $self = shift; my ($ifnx) = @_;
   my $src = 'addltxns';
   my $addltxnfnm = $ifnx . $src;
   if( -e $addltxnfnm ) {
      print "addltxnfnm $addltxnfnm\n\n";
      my $rdesc = '\w.*\w';
      open my $ifh, '<', $addltxnfnm or die "abend cannot open $addltxnfnm for reading: $!\n";
      while (my $line = <$ifh>) {
         chomp $line;
         if( $line =~ m"\S" ) {
            my ($holder,$dt,$txcents,$desc) = $line =~ m"^($rdesc):\s+(\d{4}\-\d{2}\-\d{2})\s+(\d+)\s+($rdesc)";
            die "bad format in $addltxnfnm: $_\n" unless $desc;
            showtxn( $holder,$dt,$txcents,$desc );
            $self->add_txn( 'charge', $holder, $dt, $txcents, $desc, $holder, $src );
            }
         }
      print "\n";
      }
   }
sub process_stmt_p2t { my($p2tfnm,$spref,$init_sp_key,$ar_export_txntypes,$opts) = @_;
   -e $p2tfnm or croak "$p2tfnm is not a file\n";
   # does not produce desired results:
   # my($ifnmname, $ifnmdirs, $ifnmsuffix) = fileparse($ifnm);
   # print "$ifnm, $ifnmname, $ifnmdirs, $ifnmsuffix\n";
   my ($ifnx) = $p2tfnm =~ m"(.+\.)[^.]+$";
   my $self = {
      p2tfnm => $p2tfnm,
      section_parsers => $spref,
      sections_seen => [],
      opts => $opts,
      };
   bless $self;
   require './AccountId.pl' or die;
   $self->{acctId} = &AccountId;  # print "acctId $self->{acctId}\n";
   $self->_rdAddlTxns( $ifnx );
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
   for my $type ( sort keys %{$self->{txnByDate}} ) {
      $self->{txnsByType}{$type} = $_byDateToList->( $self, $type );
      }

   print "\ncross-checking\n\n";

   for my $totalnm ( sort keys %{$self->{txnByTotal}} ) {
      defined($self->{txnTypeTotal}{$totalnm}) or croak "totalnm $totalnm has no total\n";
      $self->{txnTypeTotal}{$totalnm} == 0 or defined($self->{txnByTotal}{$totalnm}) or croak "txtype $totalnm has no txns\n";
      my $txsum = 0; map { $txsum += $_->{cents} } @{$self->{txnByTotal}{$totalnm}};
      my $anno = $self->{totalnmToTxtype}{$totalnm} eq $totalnm ? $totalnm : $self->{totalnmToTxtype}{$totalnm} .'::'. $totalnm;
      cross_chk_totals( $self->{txnTypeTotal}{$totalnm} || 0, $txsum, $anno );
      }

   $self->_section_parsers_report();

   if( 0 ) {  # various debug variants
      # print Data::Dumper->Dump([$self->{txnByDate}, $self->{txnsByType}], [qw(txnByDate txnsByType)]);
        print Data::Dumper->Dump([$self->{txnByDate} ], [qw(txnByDate )]);
        print Data::Dumper->Dump([$self->{txnsByType}], [qw(txnsByType)]);
      }

   {
   my $ofnm = $ifnx . 'DDump';
   open my $ofh, '>', $ofnm or croak "abend cannot open $ofnm for writing: $!\n";
   print $ofh Data::Dumper->Dump([$self->{txnsByType}], [qw(txnsByType)]);
   }
   {
   my $ofnm = $ifnx . 'csv';
   open my $ofh, '>', $ofnm or croak "abend cannot open $ofnm for writing: $!\n";
   my @hdr = qw( date dc description stmtId );
  #print $ofh join( ',', map { '"'.$_.'"' } @hdr ), "\n";
   for my $txntype ( sort @{$ar_export_txntypes} ) {
      for ( @{$self->{txnsByType}{$txntype}} ) {
         print $ofh join( ',', map { '"'.$_.'"' } @{$_}{@hdr} ), "\n";
         }
      }
   }
   print "\ndone\n";
   }

1;
