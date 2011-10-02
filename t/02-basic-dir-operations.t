use strict;
use warnings;
use Test::More tests => 5;
use Test::Mock::FileSystem;

my $dir        = ( $^O eq 'Win32' ) ? 'C:\temp\somedir' : '/tmp/somedir';
my $parent_dir = ( $^O eq 'Win32' ) ? 'C:\temp'         : '/tmp';

mock_dir $dir;

my $dh;
ok( opendir( $dh, $parent_dir ), 'Open directory' );
is( readdir($dh), '.',       'This directory' );
is( readdir($dh), '..',      'Parent directory' );
is( readdir($dh), 'somedir', 'Parent directory' );
ok( closedir($dh), 'Close directory' );
