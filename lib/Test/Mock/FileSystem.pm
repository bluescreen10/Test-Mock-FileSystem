package Test::Mock::FileSystem;

use strict;
use warnings;
use File::Spec;
use POSIX qw(ceil getgid getuid);

=head1 NAME

Mock::FileSystem - Simulate filesystem resources to help testing modules that depends on filesystem objects

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Some::Module;
    use Test::Mock::FileSystem 'Some::Module';

    mock_file '/tmp/something' => (
        path     => "/tmp/something",
        content  => "Some content",
        mode     => oct("4"),         # read-only
        ctime    => time() - 3600,    # one hour ago
    );

    # Then a sub in Some::Module
    sub open_file {
        my $self = shift;
        open my $fh, '<', '/tmp/something';

        # This will print Some content
        print <$fh>;

        close $fh;
    }
    
    ...

=cut

my $file_system = {};
my $block_size  = 4096;

sub import {
    my ( $class, @modules ) = @_;

    my $package = caller;

    _export_functions_to($package);

    unless (@modules) {
        push @modules, $package;
    }

    if (@modules) {
        _override_builtins($_) for @modules;
    }
    else {
        _override_builtins($package);
    }
}

=head1 EXPORTED FUNCTIONS

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head2 mock_dir $file => %options

=cut

sub mock_dir {
    my $path = shift;
    my $args = shift || {};

    my ( $vol, $dir ) = File::Spec->splitpath( $path, 1 );

    my @dirs = File::Spec->splitdir($dir);

    unshift @dirs, $vol if $vol;

    my $entry = $file_system;
    foreach (@dirs) {
        next unless $_;
        if ( $entry->{$_} ) {
            unless ( $entry->{type} eq 'd' ) {
                die "Not a Directory";
            }
            $entry = $entry->{$_}->{content};
        }

        # Create it
        else {
            $entry->{$_} = {
                type    => 'd',
                content => {},
            };
            $entry = $entry->{$_}->{content};
        }
    }
    return $entry;
}

=head2 C<mock_file $file =E<gt> %options>

This will create a C<$file> in the virtual file system and the parents directories. Additionally you can control the meta information of the file using the C<%options> parameter. Here is a list of the valid options 

=over 4

=item C<content =E<gt> $content>

The fills the virtual file with C<$content>. By default file have no content

=item C<access =E<gt> $access>

Use this option to control the access bits of the file. The available bits are B<u g k r w x>. So for example if C<$access> is the value C<oct("6")> the file will be readable and writable.

=item C<uid =E<gt> $uid>

The option C<uid> sets the owner of the file with C<$uid>. The default value is whatever C<POSIX::getuid()> returns.

=item C<gid =E<gt> $gid>

The option C<gid> sets the owning group of the file with C<$gid>. The default value is whatever C<POSIX::getgid()> returns

=item C<atime =E<gt> $time>

The option C<atime> set the access time with C<$time>. The default value is the value returned by C<time()> at the moment of file creation

=item C<ctime =E<gt> $time>. 

The option C<ctime> set the create time with C<$time>. The default value is the value returned by C<time()> at the moment of file creation

=item C<mtime =E<gt> $time>

The option C<mtime> set the modified time with C<$time>. The default value is the value returned by C<time()> at the moment of file creation

=back

=cut

sub mock_file {
    my $path = File::Spec->rel2abs(shift);
    my %args = @_;

    my $content = $args{content} || '';
    $args{content} = \$content;
    $args{access} ||= 7;
    $args{uid}    ||= getuid();
    $args{gid}    ||= getgid();
    $args{ctime}  ||= time();
    $args{mtime}  ||= time();
    $args{atime}  ||= time();
    $args{type} = 'f';

    my ( $vol, $dir, $name ) = File::Spec->splitpath($path);

    my $dir_path = File::Spec->catpath( $vol, $dir );

    # Mock the route to it
    my $entry = mock_dir $dir_path => (
        uid     => $args{uid},
        gid     => $args{gid},
    );

    $entry->{$name} = \%args;
}

sub _export_functions_to {
    my $package = shift;

    no strict 'refs';

    *{"$package\::mock_file"} = \&mock_file;
    *{"$package\::mock_dir"}  = \&mock_dir;

    use strict 'refs';

}

sub _override_builtins {
    my $package = shift;

    no strict 'refs';

    *{"$package\::open"}     = \&_open;
    *{"$package\::close"}    = \&_close;
    *{"$package\::stat"}     = \&_stat;
    *{"$package\::unlink"}   = \&_unlink;
    *{"$package\::opendir"}  = \&_opendir;
    *{"$package\::closedir"} = \&_closedir;
    *{"$package\::readdir"}  = \&_readdir;
    *{"$package\::seekdir"}  = \&_seekdir;
    *{"$package\::telldir"}  = \&_telldir;
    *{"$package\::mkdir"}    = \&_mkdir;
    *{"$package\::rmdir"}    = \&_rmdirm;

    use strict 'refs';
}

sub _close {
    CORE::close( $_[0] );
}

sub _closedir {
    my $dh = \$_[0];
    $$dh = undef;
    return 1;
}

sub _mkdir { }

sub _open {

    #my ( $fh, $access, $name ) = @_;

    my $name = $_[2] || '';
    my $compound = "$_[1] $_[2]";
    my $access;
    if ( $compound =~ /\s*(<|>|>>|\+<|\+>|\+>>)?\s*(\S+)\s*/ ) {
        $access = $1 || '<';
        $name = $2;
    }
    else {
        die 'Unexpected open() parameters for file mocking';
    }

    my $entry = _getpath($name);

    if ( not defined $entry ) {
        $! = 2;
        return 0;
    }

    return CORE::open( $_[0], $access, $entry->{content} );
}

sub _opendir {
    my $dh   = \$_[0];
    my $path = $_[1];

    my $entry = _getpath($path);

    if ( not defined $entry ) {
        $! = 2;
        return undef;
    }

    my $dir_handle = {
        index   => 0,
        content => [ '.', '..' ],
    };

    foreach ( keys %{ $entry->{content} } ) {
        push @{ $dir_handle->{content} }, $_;
    }

    $$dh = $dir_handle;
}

sub _readdir {
    my $dh = shift;

    my $current_index = $dh->{index};
    my $last_index    = scalar( @{ $dh->{content} } ) - 1;

    if ( wantarray() ) {

        $dh->{index} = $last_index;
        return @{ $dh->{content} }[ $current_index .. $last_index ];
    }
    else {
        unless ( $current_index > $last_index ) {
            $dh->{index} = $current_index + 1;
            return $dh->{content}->[$current_index];
        }
    }
}

sub _rmdir { }

sub _seekdir {
    my ( $dh, $pos ) = @_;
    $dh->{index} = $pos;
}

sub _stat ($) {
    my $filename = shift;

    my $entry = _getentry($filename);

    if ($entry) {
        my $size = _calculate_size($entry);

        return (
            1,                 # dev id,
            1,                 # inode id
            $entry->{mode},    # mode
            0,                 # number of harlinks to file
            1,                 # uid
            1,                 # gid
            0,                 # rdev
            $size,             # size
            $entry->{atime} || time(),    # atime,
            $entry->{mtime} || time(),    # mtime,
            $entry->{ctime} || time(),    # ctime,
            $block_size,                                 # blksize
            ceil( $size / $block_size ) * $block_size    # number of bloks
        );
    }
}

sub _sysopen {
    die "_sysopen\n";
}

sub _telldir {
    my $dh = shift;
    return $dh->{index};
}

sub _unlink { }

sub _utime { }

sub _getpath {
    my $path = shift;

    my ( $vol, $dir, $file ) = File::Spec->splitpath($path);

    my @dirs = File::Spec->splitdir($dir);

    unshift @dirs, $vol if $vol;
    push @dirs, $file if $file;

    my $last = pop @dirs;

    my $entry = $file_system;
    foreach (@dirs) {
        next unless $_;
        return undef unless $entry->{$_};

        unless ( $entry->{$_}->{type} eq 'd' ) {
            die "Not a Directory";
        }

        $entry = $entry->{$_}->{content};
    }

    return $entry->{$last};
}

sub _calculate_size {
    my $file = shift;

    my $size = 0;

    if ( $file->{type} eq 'f' && $file->{content} ) {
        $size = length( $file->{content} );
    }

    return $size;
}

=head1 SUBROUTINES/METHODS

=head2 function1

=cut

sub function1 {
}

=head2 function2

=cut

sub function2 {
}

=head1 AUTHOR

Mariano Waghlmann, C<< <dichoso _at_ gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-mock-filesystem at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Mock-FileSystem>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Mock::FileSystem


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Mock-FileSystem>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Mock-FileSystem>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Mock-FileSystem>

=item * Search CPAN

L<http://search.cpan.org/dist/Mock-FileSystem/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Mariano Waghlmann.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of Test::Mock::FileSystem

