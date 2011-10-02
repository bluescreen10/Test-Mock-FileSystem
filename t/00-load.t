#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Test::Mock::FileSystem' ) || print "Bail out!\n";
}

diag( "Testing Test::Mock::FileSystem $Mock::FileSystem::VERSION, Perl $], $^X" );
