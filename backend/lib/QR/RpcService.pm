package QR::RpcService;
use strict;
use warnings;

use QR::Exception qw(mkerror);
use QR::Cache;

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
    getEntry => 2,
    putEntry => 2,
    getRowCount => 2,
    getRows => 2,
);

has 'controller';

has 'config';
has 'database';
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

sub getConfig {
    my $self = shift;
    my $cfg = $self->config->cfg;
    return {
        RESERVATION => $cfg->{RESERVATION},
        USER => $cfg->{USER},
        ADDRESS => $cfg->{ADDRESS},
        ROOM => $cfg->{ROOM},
        GENERAL => {
            title => $cfg->{GENERAL}{title}
        }
    }
}

=head2 getCalendarDay(date)

Call corresponding method in L<QR::Database> to get calendar info on the given day.

=cut  

sub getCalenarDay {
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
    my $userId= $db->login($email,$key,$data);
    if ($self->
    $self->controller->session('userId',$userId);
    $db->userId($userId);
    $self->controller->session('adminMode', $self->config->cfg->{GENERAL}{admin}{$email});
    my $user = $self->getEntry('user',$seuserId);
    my $addrs = $self->getRows('addr',1000,0);  
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
        addrs => $addr
    }
}

=head2 setAddress(addrId)

Call the corresponding method in L<QR::Database> to select the billing address.

=cut

sub setAddress {
    my $self = shift;
    return $self->database->setAddress(@_); 
}

=head2 getNodeCount(expression)

Get the number of nodes matching filter.

=cut  

sub getNodeCount {  ## no critic (RequireArgUnpacking)
    my $self = shift;
    return $self->cache->getNodeCount(@_);
}

=head2 getNodes(expression,limit,offset)

Get the nodes matching the given filter.

=cut  

sub getNodes {   ## no critic (RequireArgUnpacking)
    my $self = shift;
    return $self->cache->getNodes(@_);
}

=head2 getVisualizers(type,recordId)

return a list of visualizers ready to visualize the given node.
see L<QR::Visualizer::getVisualizers> for details.

=cut

sub getVisualizers {
    my $self = shift;
    my $type = shift;
    my $recId = shift;
    my $record = $self->cache->getNode($recId);
    $self->visualizer->controller($self->controller);
    return $self->visualizer->getVisualizers($type,$record);
}

=head2 visualize(instance,args)

generic rpc call to be forwarere to the rpcService method of the visualizer instance.

=cut

sub visualize {   ## no critic (RequireArgUnpacking)
    my $self = shift;
    my $instance = shift;
    $self->visualizer->controller($self->controller);
    return $self->visualizer->visualize($instance,@_);
}

=head2 saveDash(config,label,id,update)

Save the given dashboard properties. Returns the id associated. If the id is
'null' a new id will be created. If the id is given, but the update time is
different in the dash on file, then a new copy of the dash will be written
to disk and appropriate information returned

Returns:

 { id => x, up => y }

=cut

sub saveDash {
    my $self = shift;
    return $self->cache->saveDash(@_);
}

=head2 deleteDash(id,update)

Remove the give Dashboard from the server if id AND updateTime match. Return
1 on success.

=cut

sub deleteDash {
    my $self = shift;
    return $self->cache->deleteDash(@_);
}

=head2 getDashList(lastUpdate)

Return a list of Dashboards on file, supplying detailed configuration data for those
that changed since lastFetch (epoch time).

 [
    { id => i1, up => x1, cfg => z1 }
    { id => i2, up => x2, cfg => z2 }
    { id => i3 }
 ]

=cut

sub getDashList {
    my $self = shift;
    return $self->cache->getDashList(@_);
}        

1;
__END__

=head1 COPYRIGHT

Copyright (c) 2011 by OETIKER+PARTNER AG. All rights reserved.

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

 2011-01-25 to Initial

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
