requires 'perl', '5.008005;';
requires 'Nephia', '>= 0.87';
requires 'Router::Boom', '>= 1.01';
requires 'Data::Util', '>= 0.63';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

