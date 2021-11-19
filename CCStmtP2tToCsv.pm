package CCStmtP2tToCsv;

use strict;
use warnings;
use Carp 'croak';
use Data::Dumper;

$Data::Dumper::Sortkeys = 1;

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
sub add_txn { my $self = shift; my ($txtype,$postdate,$cents,$descr,$ctx,$src) = @_;
   my %txn = ( txtype=>$txtype, date=>$postdate, cents=>$cents, description=>$descr );
   $txn{context} = $ctx if defined $ctx;
   $txn{srcdoc}  = $src if defined $src;
   push @{$self->{txnByDate}{$txtype}{$postdate}}, \%txn;
   }

sub set_total { my $self = shift; my ($txtype,$cents) = @_;
   croak "multiple definitions of txnTypeTotal[$txtype]\n" if exists $self->{txnTypeTotal}{$txtype};
   $self->{txnTypeTotal}{$txtype} = $cents;
   printf "total $txtype = %s\n", MyMods::StmtToCsv::cents_to_dc($cents);
   }

sub set_stmtCloseDate { my $self = shift; my ($closeDate) = @_;
   croak "multiple calls to set_stmtId\n" if exists $self->{closeDate};
   $self->{closeDate} = $closeDate;
   }

my $_byDateToList = sub { my ($self,$type) = @_;  # private manually called helper method
   my $bdthref = $self->{txnByDate}{$type};
   my ($srcFnm, $acctId, $closeDt) = ($self->{p2tfnm},$self->{acctId},$self->{closeDate});  # efficiency
   my @rslt;
   for my $dt ( sort keys %$bdthref ) {
      for( my $ix=0 ; $ix < scalar @{$bdthref->{$dt}} ; ++$ix ) {
         $bdthref->{$dt}[$ix]{dtsnum}   = $ix;  # modify source!
         $bdthref->{$dt}[$ix]{srcdoc} ||= $srcFnm;  # modify source (denormalize)
         $bdthref->{$dt}[$ix]{acctId}   = $acctId;  # modify source (denormalize)
         $bdthref->{$dt}[$ix]{closeDt}  = $closeDt; # modify source (denormalize)
         $bdthref->{$dt}[$ix]{stmtId}   = $acctId .'+closedt='. $closeDt; # modify source (denormalize)
         push @rslt, $bdthref->{$dt}[$ix];
         }
      }
   return \@rslt;
   };

sub _atstart { my $self = shift;
   my $ifnm = $self->{p2tfnm};
   -e $ifnm or croak "$ifnm is not a file\n";
   # does not produce desired results:
   # my($ifnmname, $ifnmdirs, $ifnmsuffix) = fileparse($ifnm);
   # print "$ifnm, $ifnmname, $ifnmdirs, $ifnmsuffix\n";
   my ($ifnx) = $ifnm =~ m"(.+\.)[^.]+$";
   my $addltxnfnm = $ifnx . 'addltxns';
   if( -e $addltxnfnm ) {
      print "$addltxnfnm $addltxnfnm\n\n";
      open my $ifh, '<', $addltxnfnm or die "abend cannot open $addltxnfnm for reading: $!\n";
      while (my $line = <$ifh>) {
         chomp $line;
         if( $line =~ m"\S" ) {
            my $rdesc = '\w.*\w';
            my ($holder,$dt,$txcents,$desc) = $line =~ m"^($rdesc):\s+(\d{4}\-\d{2}\-\d{2})\s+(\d+)\s+($rdesc)";
            die "bad format in $addltxnfnm: $_\n" unless $desc;
            MyMods::StmtToCsv::showtxn( $holder,$dt,$txcents,$desc );
            $self->add_txn( 'charge', $dt, $txcents, $desc, $holder, 'addltxns' );
            }
         }
      print "\n";
      }
   }
sub process_stmt_p2t { my($p2tfnm,$spref,$init_sp_key,$required_checked_txntypes,$opts) = @_;
   my $self = {
      p2tfnm => $p2tfnm,
      section_parsers => $spref,
      sections_seen => [],
      opts => $opts,
      };
   bless $self;
   require './AccountId.pl' or die;
   $self->{acctId} = &AccountId;  # print "acctId $self->{acctId}\n";
   $self->_atstart();
   print "$p2tfnm\n\n";
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
   for my $type ( sort keys %{$self->{txnByDate}} ) {
      $self->{txnsByType}{$type} = $_byDateToList->( $self, $type );
      }

   print "\ncross-checking\n\n";
   for my $txtype ( @{$required_checked_txntypes} ) {
      defined($self->{txnTypeTotal}{$txtype}) or croak "txtype $txtype has no total\n";
      $self->{txnTypeTotal}{$txtype} == 0 or defined($self->{txnsByType}{$txtype}) or croak "txtype $txtype has no txns\n";
      my $txsum = 0; map { $txsum += $_->{cents} } @{$self->{txnsByType}{$txtype}};
      MyMods::StmtToCsv::cross_chk_totals( $self->{txnTypeTotal}{$txtype} || 0, $txsum, $txtype );
      }

   $self->_section_parsers_report();

   if( 0 ) {  # various debug variants
      # print Data::Dumper->Dump([$self->{txnByDate}, $self->{txnsByType}], [qw(txnByDate txnsByType)]);
        print Data::Dumper->Dump([$self->{txnByDate} ], [qw(txnByDate )]);
        print Data::Dumper->Dump([$self->{txnsByType}], [qw(txnsByType)]);
      }

   print Data::Dumper->Dump([$self->{txnsByType}], [qw(txnsByType)]);
   }

1;
