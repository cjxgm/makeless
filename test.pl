
while (<>) {
	chomp;
	print;
	print ":\n";
	while ($_ =~ m{(\\.|[^\\ ])+}g) {
		print "  ", $&, "\n";
	}
}

