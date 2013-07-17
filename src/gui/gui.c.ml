# vim: noet ts=4 sw=4 sts=0 ft=perl

my @olds;

(
	enter => sub {
		@olds = ($ud::ccflags);
		$ud::ccflags .= " -DNOTHING=''";
	},
	leave => sub {
		($ud::ccflags) = @olds;
	},
)

