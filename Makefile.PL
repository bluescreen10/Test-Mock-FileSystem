use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Mock::FileSystem',
    AUTHOR              => q{Mariano Waghlmann <dichoso _at_ gmail.com>},
    VERSION_FROM        => 'lib/Test/Mock/FileSystem.pm',
    ABSTRACT_FROM       => 'lib/Test/Mock/FileSystem.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'File::Spec' => 0,
        'POSIX'      => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Test-Mock-FileSystem-*' },
);
