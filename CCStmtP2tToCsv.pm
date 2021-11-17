package CCStmtP2tToCsv;

use strict;
use warnings;
use Data::Dumper;

$Data::Dumper::Sortkeys = 1;

sub updt_section_hdr_re { my $self = shift;  # private method
   my $reraw = '(?!)';  # never matches  https://stackoverflow.com/a/4589566
      $reraw = '^\s*(' . join( '|', sort keys %{$self->{section_parsers}} ) . ')\b' if %{$self->{section_parsers}};
   print "updt_section_hdr_re = $reraw\n" if $self->{opts}{v};
   $self->{section_hdr_re} = qr{$reraw};
   }
sub found_section_hdr { my $self = shift; my ($lphdr) = @_;
   my ($lpnorm) = $lphdr =~ s!\s+! !gr;
   my ($lprex ) = $lphdr =~ s!\s+!\\s+!gr;
   die "$lphdr missing!\n" unless exists $self->{section_parsers}{ $lprex };
   print "lineparser = $lpnorm\n" if $self->{opts}{v};
   my $lpsub = delete( $self->{section_parsers}{ $lprex } );
   $self->updt_section_hdr_re();
   push @{$self->{sections_seen}}, $lpnorm;
   return $lpsub;
   }
sub section_parsers_report { my $self = shift;
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

sub add_total { my $self = shift; my ($txtype,$cents) = @_;
   die "multiple definitions of txnTypeTotal[$txtype]\n" if exists $self->{txnTypeTotal}{$txtype};
   $self->{txnTypeTotal}{$txtype} = $cents;
   printf "total $txtype = %s\n", MyMods::StmtToCsv::cents_to_dc($cents);
   }

sub set_stmtId { my $self = shift; my ($acctnum, $closeDate) = @_;
   die "multiple calls to set_stmtId\n" if exists $self->{stmtId};
   $self->{stmtId} = $acctnum . '_closed_' . $closeDate;
   }

my $byDateToList = sub { my ($bdthref) = @_;
   my @rslt;
   for my $dt ( sort keys %$bdthref ) {
      for( my $ix=0 ; $ix < scalar @{$bdthref->{$dt}} ; ++$ix ) {
         $bdthref->{$dt}[$ix]{dtsnum} = $ix;  # modify source!
         push @rslt, $bdthref->{$dt}[$ix];
         }
      }
   return \@rslt;
   };

sub atstart { my $self = shift;
   my $ifnm = $self->{p2tfnm};
   -e $ifnm or die "$ifnm is not a file\n";
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
sub add_section_hdr { my $self = shift; my ($hdr,$coderef) = @_;
   $self->{section_parsers}{ $hdr } = $coderef;
   $self->updt_section_hdr_re();
   }
sub process_stmt_p2t { my($p2tfnm,$spref,$init_sp_key,$required_checked_txntypes,$opts) = @_;
   my $self = {
      p2tfnm => $p2tfnm,
      section_parsers => $spref,
      sections_seen => [],
      opts => $opts,
      };
   bless $self;
   $self->atstart();
   print "$p2tfnm\n\n";
   open my $ifh, '<', $p2tfnm or die "abend cannot open $p2tfnm for reading: $!\n";
   my $lineparser = $self->found_section_hdr( $init_sp_key );
   while( <$ifh> ) { chomp;  # print "new line = $_\n";
      if( m"$self->{section_hdr_re}" ) {
         $lineparser = $self->found_section_hdr( $1 );
         }
      elsif( $lineparser ) {
         $lineparser->( $self );
         }
      }
   for my $type ( sort keys %{$self->{txnByDate}} ) {
      $self->{txnsByType}{$type} = $byDateToList->( $self->{txnByDate}{$type} );
      }

   print "\ncross-checking\n\n";
   for my $txtype ( @{$required_checked_txntypes} ) {
      defined($self->{txnTypeTotal}{$txtype}) or die "txtype $txtype has no total\n";
      $self->{txnTypeTotal}{$txtype} == 0 or defined($self->{txnsByType}{$txtype}) or die "txtype $txtype has no txns\n";
      my $txsum = 0; map { $txsum += $_->{cents} } @{$self->{txnsByType}{$txtype}};
      MyMods::StmtToCsv::cross_chk_totals( $self->{txnTypeTotal}{$txtype} || 0, $txsum, $txtype );
      }

   $self->section_parsers_report();

   if( 0 ) {  # various debug variants
      # print Data::Dumper->Dump([$self->{txnByDate}, $self->{txnsByType}], [qw(txnByDate txnsByType)]);
        print Data::Dumper->Dump([$self->{txnByDate} ], [qw(txnByDate )]);
        print Data::Dumper->Dump([$self->{txnsByType}], [qw(txnsByType)]);
      }

   print Data::Dumper->Dump([$self->{txnsByType}], [qw(txnsByType)]);
   }

1;
