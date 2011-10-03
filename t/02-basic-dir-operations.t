use strict;
use warnings;
use Test::More tests => 5;
use Test::Mock::FileSystem;
use File::Spec;

my $dir = File::Spec->rel2abs( File::Spec->catdir( 'dir', 'subdir' ) );
my $parent_dir = File::Spec->rel2abs( File::Spec->catdir('dir') );

mock_dir $dir;

my $dh;
ok( opendir( $dh, $parent_dir ), 'Open directory' );
is( readdir($dh), '.',      'This directory' );
is( readdir($dh), '..',     'Parent directory' );
is( readdir($dh), 'subdir', 'Parent directory' );
ok( closedir($dh), 'Close directory' );
