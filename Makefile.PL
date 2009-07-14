use ExtUtils::MakeMaker;
WriteMakefile(
    NAME                => 'WWW::Mechanize::Cached',
    AUTHOR              => 'Olaf Alders <olaf@wundercounter.com>',
    VERSION_FROM        => 'lib/WWW/Mechanize/Cached.pm',
    ABSTRACT_FROM       => 'lib/WWW/Mechanize/Cached.pm',
    PREREQ_PM           => {
        'Carp'              => 0,
        'Cache::Cache'      => '1.02',
        'Storable'          => '2.08',
        'WWW::Mechanize'    => '1.00',
        'Test::More'        => '0.47',
        'Test::Warn'        => '0.11',
    },
    clean => { FILES => 'WWW-Mechanize-Cached-*' },
);
