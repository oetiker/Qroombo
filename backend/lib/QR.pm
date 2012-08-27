package QR;

=head1 NAME

QR - the mojo application starting point

=head1 SYNOPSIS

 use QR;
 use Mojolicious::Commands;

 $ENV{MOJO_APP} = QR->new;
 # Start commands
 Mojolicious::Commands->start;

=head1 DESCRIPTION

Configure the mojo engine to run our application logic as webrequests
arrive.

=head1 ATTRIBUTES

=cut

use strict;
use warnings;

use Mojolicious::Plugin::QooxdooJsonrpc;
use Mojo::URL;
use Mojo::Util qw(hmac_sha1_sum slurp);

use QR::RpcService;
use QR::Config;
use QR::DocPlugin;

use Mojo::Base 'Mojolicious';

=head2 config

A pointer the the L<QR::Config> object.

=cut

has 'config_file' => sub { $ENV{QROOMBO_CONF} || $_[0]->home->rel_file('etc/qroombo.cfg' ) };

has 'config' => sub {
    my $self = shift;
    QR::Config->new(
        file => $self->config_file
    );
};

=head1 METHODS

All  the methods of L<Mojolicious> as well as:

=cut

=head2 startup

Mojolicious calls the startup method at initialization time.

=cut

sub startup {
    my $self = shift;
    my $me = $self;
    my $gcfg = $self->config->cfg->{GENERAL};
    $self->secret($gcfg->{secret});
    if ($self->mode eq 'development'){
        $self->log->path(undef);    
    }
    else {      
        $self->log->path($gcfg->{log_file});
        if (not $ENV{MOJO_LOG_LEVEL} and $gcfg->{log_level}){
            $self->log->level($gcfg->{log_level});
        }
    }
    
    $self->hook( before_dispatch => sub {
        my $self = shift;
        my $uri = $self->req->env->{SCRIPT_URI} || $self->req->env->{REQUEST_URI};
        my $path_info = $self->req->env->{PATH_INFO};
        $uri =~ s|/?${path_info}$|/| if $path_info and $uri;
        $self->req->url->base(Mojo::URL->new($uri)) if $uri;
    });
    
    # session is valid for 1 month
    $self->sessions->default_expiration(30*24*3600);

    # prevent our cookie from colliding tagging it with the config file path
    $self->sessions->cookie_name('QR_'.hmac_sha1_sum($self->config_file));

    my $routes = $self->routes;

    my $apiDocRoot = $self->home->rel_dir('apidoc');
    if (-d $apiDocRoot){
        my $apiDoc = Mojolicious::Static->new();
        $apiDoc->paths([$apiDocRoot]);
        $routes->get('/apidoc/(*path)' =>  { path => 'index.html' } => sub {
            my $self = shift;
            my $file = $self->param('path') || '';
            $self->req->url->path('/'.$file); # relative paths get appended ... 
            if (not $apiDoc->dispatch($self)){
                $self->render(
                   status => 404,
                   text => $self->req->url->path.' not found'
               );
            }
        });
    }

    $self->plugin('QR::DocPlugin', {
        root => '/doc',
        index => 'QR::Index',
        localguide => $gcfg->{localguide},
        template => Mojo::Asset::File->new(
            path=>$self->home->rel_file('templates/doc.html.ep')
        )->slurp,
    }); 

    my $service = QR::RpcService->new(
        config => $self->config,
        log => $self->log
    );

    $self->plugin('qooxdoo_jsonrpc',{
        prefix => '',
        services => {
            qr => $service
        }
    }); 
    return 0;
}

1;

__END__

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=head1 COPYRIGHT

Copyright (c) 2011 by OETIKER+PARTNER AG. All rights reserved.

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2012-07-30 to 1.0 first version

=cut

# Emacs Configuration
#
# Local Variables:
# mode: cperl
# eval: (cperl-set-style "PerlStyle")
# mode: flyspell
# mode: flyspell-prog
# End:
#
# vi: sw=4 et
