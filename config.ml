# vim: noet ts=4 sw=4 sts=0 ft=perl

@ud::targets = qw[ all clean rebuild test commit ];

$ud::cc = "gcc";
$ud::ld = "gcc";
$ud::ccflags = "-std=gnu11 -march=native -Ofast -Wall "
			 . "-Wno-main";
$ud::ldflags = "-lm";
$ud::dest = "project";
$ud::test_arg = "example-argument";





sub ud::ccflags
{
	my $flags = '';
	for (@_) {
		chomp($flags .= `pkg-config --cflags $_`);
		$flags =~ s/\s+$//g;
		$flags .= ' ';
	}
	$flags;
}

sub ud::ldflags
{
	my $flags = '';
	for (@_) {
		chomp($flags .= `pkg-config --libs $_`);
		$flags =~ s/\s+$//g;
		$flags .= ' ';
	}
	$flags;
}




(
	all => {
		require => [qw[ compile build ]],
	},

	clean => {
		pre => sub {
			unlink <lpp-elm-ui.*.db>;
			system "rm -rf build";
		},
	},

	rebuild => {
		require => [qw[ clean all ]],
	},

	test => {
		pre => sub {
			system "./build/$ud::dest $ud::test_arg";
		},
	},

	commit => {
		require => [qw[ clean ]],
		post => sub {
			system "git add .";
			system "git diff --cached";
			system "env LANG=C git commit -a";
		},
	},




	compile => {
		source => [qw[ src ]],
		pre => sub {
			mkdir "build";
		},
		dir_enter => sub {
			mkdir "build/@_";
		},
		file => sub {
			my ($file) = @_;
			return if $file !~ /^(.*)\.c$/;
			my $obj = "build/$1.o";

			system "env LANG=C $ud::cc $file -c -o $obj $ud::ccflags" and die;
		},
		dirty => sub {
			my ($file) = @_;
			return 0 if $file !~ /^(.*)\.c$/;
			my $obj = "build/$1.o";

			my $dirty = &ml::newer($file, $obj);
			return 1 if $dirty;

			my $deps = `gcc -MM $ud::ccflags $file`;
			$deps =~ s/\\\n/ /gm;
			$deps =~ s/^[^:]+:\s*//gm;
			for (split /\s+/, $deps) {
				return 1 if &ml::newer($_, $obj);
			}

			0;
		},
	},

	build => {
		source => [qw[ build/src ]],
		pre => sub {
			@ud::objs = ();
			$ud::dirty = 0;
		},
		file => sub {
			push @ud::objs, "@_";
		},
		dirty => sub {
			$ud::dirty |= &ml::newer("@_", "build/$ud::dest");
			1;
		},
		post => sub {
			if ($ud::dirty) {
				system "env LANG=C $ud::ld -o build/$ud::dest @ud::objs $ud::ldflags";
			}
			else { print "\e[0;30;42m skip \e[0m\n" }
		},
	},
)

