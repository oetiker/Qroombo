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
    logout => 1,
    sendKey => 1,
    getForm => 1,
    getTabView => 1,
    getPrice => 1,
    setAddrId => 2,
    getEntry => 3,
    putEntry => 3,
    removeEntry => 3,
    getRowCount => 3,
    getRows => 3,
);

has 'controller';

has 'config' => sub {croak "config property is required"};

has 'database' => sub { my $self = shift; QR::Database->new(config => $self->config, log => $self->log ) };
has 'log'   => sub {croak "log property is required"};

sub allow_rpc_access {
    my $self = shift;
    my $method = shift;    
    my $userId = $self->controller->session('userId');
    my $addrId = $self->controller->session('addrId');
    my $adminMode = $self->controller->session('adminMode');
    $self->database->userId($userId);
    $self->database->addrId($addrId);
    $self->database->adminMode($adminMode);
    die mkerror(3948,q{access denied}) unless $allow{$method};
    die mkerror(8833,"anonymous access denied ($method)") if $allow{$method} > 1 and not $userId;
    die mkerror(3844,q{billing address required}) if $allow{$method} > 2 and not $addrId;
    return $allow{$method}; 
}
   

=head2 getConfig()

get some gloabal configuration information into the interface

=cut

sub getConfig {
    my $self = shift;
    my $cfg = $self->config->cfg;
    my $db = $self->database;
    my $ret = {
        cfg => {
            reservation => $cfg->{RESERVATION},
            room => $cfg->{ROOM},
            general => {
                title => $cfg->{GENERAL}{title},
                currency => $cfg->{GENERAL}{currency},
            }
        },
        tabView => {
            map {
                $_ => $db->getTableView($_)
            } qw(resv user addr acct)
        }
    };
    my $userId = $self->controller->session('userId');
    my $adminMode = $self->controller->session('adminMode');    
    $db->adminMode($adminMode);
    if ($userId){
        $ret->{user} = $db->getEntry('user',$userId);
        $ret->{addrs} = $db->getRows('addr',1000,0);
    }
    return $ret;
}

=head2 getForm(table)

Call corresponding method in L<QR::Database> to get the autoform description
for the given table.

=cut  

sub getForm {
    my $self = shift;    
    return $self->database->getForm(@_);
}

=head2 getTabView(table)

Call corresponding method in L<QR::Database> to get the definition for the view table.

=cut  

sub getTabView {
    my $self = shift;    
    return $self->database->getTabView(@_);
}

=head2 getCalendarDay(date)

Call corresponding method in L<QR::Database> to get calendar info on the given day.

=cut  

sub getCalendarDay {
    my $self = shift;    
    return $self->database->getCalendarDay(@_); 
}

=head2 sendKey(email)

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
    my $userData = shift;
    my $addrData = shift;
    my $db = $self->database;
    my $userId = $db->login($email,$key,$userData,$addrData);
    $self->controller->session('userId',$userId);
    $db->userId($userId);
    my $adminMode = $self->config->cfg->{GENERAL}{admin}{$email};
    $self->controller->session('adminMode', $adminMode);
    $db->adminMode($adminMode);
    my $user = $db->getEntry('user',$userId);
    $self->setAddrId($user->{user_addr});
    return {
        user => $user,
        addrs => $db->getRows('addr',1000,0)
    }
}

=head2 logout()

remove the session authorization from the client

=cut

sub logout {
    my $self = shift;
    $self->controller->session('adminMode',undef);
    $self->controller->session('userId',undef);
    $self->controller->session('addrId',undef);
    return 1;
}


=head2 setAddrId(addrId)

Call the corresponding method in L<QR::Database> to select the billing
address and return appropriate forms for editing the data.

=cut

sub setAddrId {
    my $self = shift;
    my $addrId = $self->database->setAddrId(@_); 
    $self->controller->session('addrId',$addrId);
    return $addrId;
}

=head2 putEntry(table,recId,rec)

Update or add the given entry in the database. If recId is null
a new entry is created.

=cut

sub putEntry {
    return shift->database->putEntry(@_);
}

=head2 getEntry(table,recId)

Return the given entry in the database. If recId is null
a new entry is created.

=cut

sub getEntry {
    return shift->database->getEntry(@_);
}

=head2 removeEntry(table,recId)

Remove the indicated entry from the database

=cut

sub removeEntry {
    return shift->database->removeEntry(@_);
}

=head2 getPrice(resv)

calculate the price for the given reservation entry.

=cut

sub getPrice {
    return shift->database->getPrice(@_);
}

=head2 getRowCount(table,search)

Get the number of table rows.

=cut  

sub getRowCount {  ## no critic (RequireArgUnpacking)
    my $self = shift;
    return $self->database->getRowCount(@_);
}

=head2 getRows(table,search,limit,offset,sortCol,desc?)

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
