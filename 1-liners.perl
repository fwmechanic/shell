
# count the # of characters in a file:
# -0777  enables "slurp mode": $_ contains whole file  https://riptutorial.com/perl/example/16725/slurp-file-in-one-liner
perl -0777 -ne 'my $count = $_ =~ tr/\r//; print $count' "$fnm"  # character counted is '\r' (CR)
