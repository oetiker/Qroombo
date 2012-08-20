package QR::RpcService;
use strict;
use warnings;
use Carp;

use QR::Exception qw(mkerror);
use QR::Database;

use Mojo::Base -base;

=head1 NAME

QR::RpcService - RPC services for ep

=head1 SYNOPSIS

This module gets instantiated by L<QR::MojoApp> and provides backend functionality for Extopus.
It relies on an L<QR::Cache> instance for accessing the data.

=head1 DESCRIPTION

the module provides the following methods

=cut

=head2 allow_rpc_access(method)

is this method accessible?

=cut

our %allow = (
    getCalendarDay => 1,
    getConfig => 1,
    login => 1,
    sendKey => 1,
    getEntry => 2,
    putEntry => 2,
    getRowCount => 2,
    getRows => 2,
);

has 'controller';

has 'config' => sub {croak "config property is required\n"};

has 'database' => sub { QR::Database->new(config => shift->config) };
has 'log';

sub allow_rpc_access {
    my $self = shift;
    my $method = shift;    
    my $userId = $self->controller->session('userId');
    my $addrId = $self->controller->session('addrId');
    my $adminMode = $self->controller->session('adminMode');
    $self->database->userId($userId);
    $self->database->addrId($addrId);
    $self->database->adminMode($adminMode);
    if ($allow{$method} ~~ 2 and not ( $userId and $addrId )){
        die mkerror(3993,q{authentication required});
    }
    return $allow{$method}; 
}
   

=head2 getConfig()

get some gloabal configuration information into the interface

=cut
sub _hashCleaner ($);
sub _hashCleaner ($) {
    my $hash = shift;
    return unless ref $hash eq 'HASH';
    for my $key (keys %$hash) {
        given (ref $hash->{$key}){
            when ('CODE'){
                 delete $hash->{$key};
            }
            when ('HASH'){
                 _hashCleaner $hash->{$key};
            }
        }
    }
}

sub getConfig {
    my $self = shift;
    my $cfg = $self->config->cfg;
    my $ret = {
        reservation => $cfg->{RESERVATION},
        user => $cfg->{USER},
        address => $cfg->{ADDRESS},
        room => $cfg->{ROOM},
        general => {
            title => $cfg->{GENERAL}{title}
        }
    };
    _hashCleaner $ret;
    return $ret;
}

=head2 getCalendarDay(date)

Call corresponding method in L<QR::Database> to get calendar info on the given day.

=cut  

sub getCalendarDay {
    my $self = shift;    
    return $self->database->getCalendarDay(@_); 
}

=head2 login(email,key)

Call corresponding method in L<QR::Database> to login.

=cut

sub sendKey {
    my $self = shift;    
    return $self->database->sendKey(@_); 
}

=head2 login(email,key,data)

Call corresponding method in L<QR::Database> to login.

=cut

sub login {
    my $self = shift;
    my $email = shift;
    my $key = shift;
    my $data = shift;
    my $db = $self->database;
    my $userId = $db->login($email,$key,$data);
    $self->controller->session('userId',$userId);
    $db->userId($userId);
    $self->controller->session('adminMode', $self->config->cfg->{GENERAL}{admin}{$email});
    my $user = $self->getEntry('user',$userId);
    my $addrs = $self->getRows('addr',1000,0);  

    # set the default address    
    if ($user->{user_addr}){
        for (@$addrs){
            if ($_->{addr_id} == $user->{user_addr}){
                $self->controller->session('addrId',$_->{addr_id});
                last;
            }
        }
    }
    else {
        $self->controller->session('addrId',$addrs->[0]{addr_id});
    }

    return {
        user => $user,
        addrs => $addrs
    }
}

=head2 setAddrId(addrId)

Call the corresponding method in L<QR::Database> to select the billing address.

=cut

sub setAddrId {
    my $self = shift;
    my $addrId = $self->database->setAddrId(@_); 
    $self->controller->session('addrId',$addrId);
}

=head2 getRowCount(table)

Get the number of table rows.

=cut  

sub getRowCount {  ## no critic (RequireArgUnpacking)
    my $self = shift;
    return $self->database->getRowCount(@_);
}

=head2 getRows(table,limit,offset,sortCol,sortDirection)

Get the rows.

=cut  

sub getRows {   ## no critic (RequireArgUnpacking)
    my $self = shift;
    return $self->database->getRows(@_);
}


1;
__END__

=head1 COPYRIGHT

Copyright (c) 2012 by OETIKER+PARTNER AG. All rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY 

 2012-08-19 to Initial

=cut
  
1;

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
