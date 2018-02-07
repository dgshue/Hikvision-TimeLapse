$ctr = 0;

# get first argument, i.e filename
$in_filename = shift;
print "You chose input <$in_filename>\n";
$out_filename = shift;
print "You chose output <$out_filename>\n";

open(INFILE, $in_filename) or die "can't open input file: $!";

#set infile to binary mode
binmode(INFILE);

open(OUTFILE, ">$out_filename") or die "can't open output file: $!";

while(<INFILE>) {

    @samples = split(//,$_);

    foreach $byte (@samples) { 
        print OUTFILE "0x".sprintf("%02hx",ord($byte)).", ";
        $ctr += 1;
        if (($ctr % 8) == 0) {
            print OUTFILE "\n";
            $ctr = 0;
        }
    }
}