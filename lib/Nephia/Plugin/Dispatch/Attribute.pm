package Nephia::Plugin::Dispatch::Attribute;
use 5.008005;
use strict;
use warnings;
use utf8;

our $VERSION = "0.01";

use parent 'Nephia::Plugin';
use Router::Boom;
use Data::Util;

sub exports {
    'MODIFY_CODE_ATTRIBUTES';
}

sub MODIFY_CODE_ATTRIBUTES {
    my ($self, $context) = @_;
    my $router = $self->app->{router};

    return sub {
        my ($pkg, $code, @attrs) = @_;
        my ($pkg_name, $sub_name) = Data::Util::get_code_info($code);

        my $path = '';
        my $method = 'GET';
        my $args_path = '';
        my %options = ();
        for my $attr (@attrs) {
            next unless Data::Util::is_string($attr);

            if ($attr eq 'Path') {
                $path = '/';
            }
            elsif ($attr eq 'Local') {
                $path = "/$sub_name";
            }
            elsif (
                my ($capture) = $attr =~ m!\APath\(['\"]([\w/]+)['\"]\)\z!
            ) {
                $path = "/$capture";
            }

            if (grep { $attr eq $_ } qw/POST PUT DELETE/) {
                $method = $attr;
            }

            if (
                my ($args_num) = $attr =~ m!\AArgs(?:\(([\d+])\))?\z!
            ) {
                if ($args_num) {
                    $args_path .= "/:$_" for 1..$args_num;
                }
                else {
                    $args_path = '/*';
                }
            }

            if (my ($regex) = $attr =~ m!\ARegex\(['\"](.+)['\"]\)\z!) {
                my $i = 0;
                $regex =~ s/\((.+?)\)/++$i;"{${i}:${1}}"/eg;
                $path = $regex;
            }
        }
        if ($path && $method) {
            $router->add($path.$args_path, { action => $code, method => $method });
        }
        return;
    };
}

sub new {
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(%opts);
    my $app = $self->app;
    $app->action_chain->after('Core', Dispatch => $self->can('dispatch'));
    $app->{router} = Router::Boom->new;
    $app->{app} = sub { };

    return $self;
}

sub dispatch {
    my ($app, $context) = @_;
    my $router = $app->{router};
    my $req = $context->get('req');
    my $env = $req->env;
    my $res = $app->dsl('res_404') ? $app->dsl('res_404')->() : [404, [], ['not found']];

    my $path_info = $env->{PATH_INFO};

    if (my ($orig_path_info, $captured) = $router->match($path_info)) {
        my $path_info = {%$orig_path_info};
        my $action = delete $path_info->{action};
        $context->set(path_param => $path_info);

        my @captured_args;
        if (exists $captured->{1}) {
            @captured_args = map {
                $captured->{$_}
            } (sort { $a <=> $b } keys %$captured);
        }
        elsif (exists $captured->{'*'}) {
            @captured_args = ($captured->{'*'});
        }

        $res = $action->($app, $context, @captured_args);
    }

    $context->set(res => $res);
    return $context;
}

1;
__END__

=encoding utf-8

=head1 NAME

Nephia::Plugin::Dispatch::Attribute - It's new $module

=head1 SYNOPSIS

    use Nephia::Plugin::Dispatch::Attribute;

=head1 DESCRIPTION

Nephia::Plugin::Dispatch::Attribute is ...

=head1 LICENSE

Copyright (C) mackee.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

mackee E<lt>macopy123@gmail.comE<gt>

=cut
