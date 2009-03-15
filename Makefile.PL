use 5.008;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'JavaScript::Packer',
    AUTHOR              => 'Merten Falk <nevesenin@cpan.org>',
    VERSION_FROM        => 'lib/JavaScript/Packer.pm',
    ABSTRACT_FROM       => 'lib/JavaScript/Packer.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'JavaScript-Packer-*' },
);