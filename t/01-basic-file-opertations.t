use strict;
use warnings;
use Test::More tests => 7;
use Test::Mock::FileSystem;

my $file;

if ( $^O eq 'Win32' ) {
    $file = 'C:\temp\dir\test_file';
}
else {
    $file = '/tmp/dir/test_file';
}
mock_file $file;

# Write
my $fh;
ok( open( $fh, '>', $file ), 'Open file for write' );
ok(print($fh "Hello world"), 'Write something' );
ok( close($fh), 'Close File' );

# Read
ok( open( $fh, '<', $file ), 'Open file for read' );

my $line = <$fh>;
is( $line, 'Hello world', 'Read contents' );

ok( eof($fh),   'End of file' );
ok( close($fh), 'Close File' );
