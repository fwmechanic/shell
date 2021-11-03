
package MyMods::StmtToCsv;

our $VERSION = '1.00';
use base 'Exporter';
# our @EXPORT = qw(tocents cents_to_dc showtxn);  # not necessary as I favor fully qualifying the points of call

sub tocents { my ($dcstr) = @_;  # convert currency to cents to avoid inexact floating point ops; any leading sign or $ shall have been stripped.
   $dcstr =~ s/[,]//g;
   my ($dol, $cents) = $dcstr =~ /^(\d*)\.(\d{2})$/;
   return ((($dol || 0) * 100) + $cents);
   }

sub cents_to_dc { my ($txcents) = @_;
   return sprintf "%5d.%02d", $txcents / 100, $txcents % 100;
   }

sub showtxn { my ($holder,$dt,$txcents,$desc) = @_;
   printf "%-17s: %s %s %s\n", $holder, $dt, cents_to_dc($txcents), $desc;
   }
