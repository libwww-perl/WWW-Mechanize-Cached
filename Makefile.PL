use ExtUtils::MakeMaker;
WriteMakefile(
    NAME                => 'WWW::Mechanize::Cached',
    AUTHOR              => 'Andy Lester <andy@petdance.com>',
    VERSION_FROM        => 'Cached.pm',
    ABSTRACT_FROM       => 'Cached.pm',
    PREREQ_PM           => {
        'Carp' => 0,
        'Cache::Cache' => '1.02',
        'Storable' => '2.08',
        'WWW::Mechanize' => '1.00',
        'Test::More' => '0.47',
    },
    clean => { FILES => 'WWW-Mechanize-Cached-*' },
);
