use ExtUtils::MakeMaker;
WriteMakefile(
    NAME                => 'WWW::Mechanize::Cached',
    AUTHOR              => 'Olaf Alders <olaf@wundercounter.com>',
    VERSION_FROM        => 'lib/WWW/Mechanize/Cached.pm',
    ABSTRACT_FROM       => 'lib/WWW/Mechanize/Cached.pm',
    PREREQ_PM           => {
        'Carp'              => 0,
        'Cache::Cache'      => '1.02',
        'HTTP::Headers'     => '5.827',
        'Storable'          => '2.08',
        'Test::More'        => '0.47',
        'Test::Warn'        => '0.11',
        'WWW::Mechanize'    => '1.00',
    },
    clean => { FILES => 'WWW-Mechanize-Cached-*' },
);
