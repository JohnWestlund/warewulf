use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Warewulf::Module::REST',
    AUTHOR              => q{Adam DeConinck <ajdecon@ajdecon.org>, Jason Stover <jason@r-hpc.com>},
    VERSION_FROM        => 'lib/Warewulf/Module/REST.pm',
    ABSTRACT            => 'REST API for Warewulf',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'YAML'       => 0,
        'Dancer'     => 1.3072,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Warewulf-Module-REST-*' },
);
