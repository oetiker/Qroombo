package QR::Database;
use strict;
use warnings;
use Data::Dumper;
use Time::Local;

=head1 NAME

QR::Database - qroombo database

=head1 SYNOPSIS

 use QR::Database;

 my $db = QR::Database->new(
        user => $user,
        cfg => $cfg
 );

 $db->user('tobi@oetiker.ch');

=head1 DESCRIPTION

Provide permanent storage for qroombo data.

=cut


use Mojo::Base -base;
use Carp;
use DBI;
use Encode;
use QR::Exception qw(mkerror);

my %tableNames = ( user =>1, addr=>1, adus=>1, resv=>1, acct=>1);

=head2 ATTRIBUTES

The cache objects have the following attributes

=cut

=head3 userId

the name of the current user. Some functions are also available if
no user is set.

=cut

has userId => undef;

=head3 addrId

the current billing address.

=cut

has addrId => undef;

=head3 adminMode;

are we running in admin mode ?

=cut

has adminMode => 0;

=head3 cfg

points to the config hash

=cut

has cfg  => sub { croak "The configuration object is required" };

=head3 dbh

the handle to the SQLite db

=cut

has 'dbh';

has encodeUtf8  => sub { find_encoding('utf8') };
has json        => sub { Mojo::JSON->new };


=head2 B<new>(I<config>)

Create an QR::Database object.

=over

=item B<user>

Who is talking to the database. Some functions require the user to be set.

=item B<cfg>

A hash pointer to the configuration as read by L<QR::Config>.

=back

=cut

# connect to the database
sub _connect {
    my $self = shift;
    my $path = $self->cfg->config->{GENERAL}{database_dir}.'/qroombo.sqlite';
    # $self->log->debug("connecting to sqlite cache $path");
    my $dbh = DBI->connect_cached("dbi:SQLite:dbname=$path","","",{
         RaiseError => 1,
         PrintError => 1,
         AutoCommit => 1,
         ShowErrorStatement => 1,
         sqlite_unicode => 1,
    });
    $dbh->do('PRAGMA foreign_keys = ON');
    return $dbh;
}

# Make sure the tables required by Qroombo exist
sub _ensureTables {
    my $self = shift;
    my %tables = (
        user => <<SQL_END,
user_id     INTEGER PRIMARY KEY AUTOINCREMENT,
user_email  TEXT NOT NULL UNIQUE,
user_first  TEXT,
user_last   TEXT,
user_phone1 TEXT,
user_phone2 TEXT,
user_extra  TEXT
SQL_END
        addr => <<SQL_END,
addr_id     INTEGER PRIMARY KEY AUTOINCREMENT,
addr_name   TEXT NOT NULL,
addr_org    TEXT,
addr_addr1  TEXT NOT NULL,
addr_addr2  TEXT,
addr_zip    TEXT NOT NULL,
addr_town   TEXT NOT NULL,
addr_cntry  TEXT,
addr_extra  TEXT
SQL_END
        adus => <<SQL_END,
adus_id     INTEGER PRIMARY KEY AUTOINCREMENT,
adus_addr   INTEGER NOT NULL REFERENCES user,
adus_user   INTEGER NOT NULL REFERENCES addr,
adus_admin  BOOL,
CONSTRAINT adus_unique UNIQUE(adus_addr,adus_user)
SQL_END
        resv => <<SQL_END,
resv_id     INTEGER PRIMARY KEY AUTOINCREMENT,
resv_adus   INTEGER NOT NULL REFERENCES adus,
resv_room   TEXT NOT NULL,
resv_start  DATETIME NOT NULL,
resv_len    NUMERIC NOT NULL,
resv_pub    BOOL DEFAULT FALSE,
resv_price  NUMERIC NOT NULL,
resv_subj   TEXT NOT NULL,
resv_extra  TEXT
SQL_END
        acct => <<SQL_END,
acct_id     INTEGER PRIMARY KEY AUTOINCREMENT,
acct_addr   INTEGER NOT NULL REFERENCES addr,
acct_date   DATE NOT NULL,
acct_subj   TEXT NOT NULL,
acct_value  NUMERIC,
acct_resv   INTEGER REFERENCES resv
SQL_END
        log => <<SQL_END,
log_id      INTEGER PRIMARY KEY AUTOINCREMENT,
log_date    DATE NOT NULL,
log_user    TEXT NOT NULL,
log_data    TEXT NOT_NULL
SQL_END
    );
    my $dbh = $self->dbh;
    for my $tab (keys %tables){
        $dbh->do("CREATE TABLE IF NOT EXISTS $tab ( $tables{$tab} )");
    }
}

sub new {
    my $self =  shift->SUPER::new(@_);
    $self->dbh($self->_connect());
    $self->_ensureTables();
    return $self;
}

=head2 getCalendarDay(date)

Returns the list of reservations for the given day (UTC). The date is to be given in unix epoch seconds.

=cut

sub getCalendarDay {
    my $self = shift;
    my $date = strftime('%Y-%m-%d',gmtime(shift));
    my $dbh = $self->dbh;
    my $resArray = $dbh->selecall_arrayref(<<SQL_END,{ Slice => {}},$date);
SELECT resv_id,
       resv_room,
       date(resv_start,'utc') AS date,
       strftime('%H',resv_start,'utc') AS start,
       resv_len,
       resv_pub,
       resv_subj,
       adus_addr,
       user_email
  FROM resv 
  JOIN adus ON (resv_adus = adus_id) 
  WHERE date(resv_start,'utc') = ?
SQL_END
    my @ret;
    my $addrId = $self->addrId;
    for my $res (@$resArray){
        my $mine = $res->{adus_addr} ~~ $addrId;
        push @ret, {
            room => $res->{resv_room},
            date => $res->{date},
            start => $res->{start},
            duration => $res->{resv_len},
            subj => $res->{resv_pub} or $mine ? $res->{resv_subj},
            editable => $mine
        }
    }
    return \@ret;
}


=head2 getEntry(table,entry_id)

Return a record from the given table. If the user is not authorized, the operation
will fail.

=cut

# just return the data without any checks
sub _getRawEntry {
    my $self = shift;
    my $tableIn = shift;
    my $fieldIn = shift;
    my $table = $dhb->quote_identifier($tableIn);
    my $recField = $dhb->quote_identifier($field);
    my $recId = shift;
    my $dbh = $self->dbh;
    return $dbh->selectrow_hashref("SELECT * FROM $table WHERE $recField = ?",{},$recId);
}

sub _extraFilter {
    my $self = shift;
    my $section = shift;
    my $data = shift;
    my $cfg = $self->cfg->config->{$section};
    my %ret;
    if ($cfg->{EXTRA_FIELDS_PL}){
        my $extraFields = $cfg->{EXTRA_FIELDS_PL}();
        for my $field (@$extraFields){
            my $key = $field->{key};
            $ret{$key} = $data->{$key};
        }
    }
    return \%ret;
}

sub getEntry {
    my $self = shift;
    my $table = shift;
    my $recId = shift;
    my $dbh = $self->dbh;
    my $rec = $self->_getRawEntry($table,$table.'_id',$recid);   
    my $extra = {};
    if ($rec->{$table_extra}){
        $extra = $self->json->decode($rec->{$table.'_extra'});        
    }
    my $cfg = $self->cfg->config;
    given($table){
        when ('addr'){
            my $adus = $dbh->selectrow_hashref('SELECT adus_id FROM adus WHERE adus_addr = ? AND adus_user = ?',{},$recId,$self->userId); 
            if ($self->adminMode or $adus->{adus_id}){
                my $users = $dbh->selectcol_arrayref(<<SQL_END,{Columns=>[1,2,3]},$recId);
SELECT user_email,adus_id,adus_admin
  FROM adus
  JOIN user ON ( adus_user = user_id )
 WHERE adus_addr = ?
SQL_END
                $extra = $self->_extraFilter('ADDRESS',$extra)
                return {
                    %$extra,                    
                    %$rec,
                    addr_users =>  { 
                        map { 
                            $_->[0] => { 
                                id=>$_->[1],
                                admin => $_->[2] 
                            } 
                        } @$users
                    }
                }
            }
        }
        when ('user'){
            if ($self->adminMode or $recId eq $self->userId){
                $extra = $self->_extraFilter('USER',$extra)
                return { %$extra, %$rec};
            }
        }
        when ('resv'){
            my $adus = $self->_getRawEntry('adus','adus_id',$rec->{resv_adus});
            if ( $self->adminMode 
                or $adus->{adus_user} ~~ $self->userId 
                or $adus->{adus_addr} ~~ $self->addrId ){
                $extra = $self->_extraFilter('RESERVATION',$extra)
                return { %$extra, %$rec};
            }
        }
        when ('acct'){
            if ( $self->adminMode
               or $rec->{acct_addr} ~~ $self->addrId ){
                return $rec;
            }
        }
        when ('adus'){
            if ( $self->adminMode
               or $rec->{adus_addr} ~~ $self->addrId ){
               return $rec;
            }
        }
    }
    die mkError(39934,'Record acccess permission denied');
}

=head2 putEntry(table,id,rec)

Store an entry into the table. If the id is given, overwrite an existing
entry (given the permissions are correct) or if the id is empty, create a
new entry (again checking the permissions first).

=cut

sub putEntry {
    my $self = shift;
    my $table = shift;
    my $recId = shift;
    my $rec = shift;
    # can't change or set the id of a record
    delete $rec->{$table.'_id'};
    my $extra;
    given ($table) {
        when ('addr'){                       
            $adus = $dbh->selectrow_hashref('SELECT adus_id FROM adus WHERE adus_admin AND adus_addr = ? AND adus_user = ?',{},$recId,$self->userId);
            die mkError(95334,"No premission to edit address record")
                unless $adus->{adus_id} or not $recId or $self->adminMode;
        }
        when ('user'){
            die mkError(38344,"No permission to edit user details")
                unless not $recId or $recId ~~ $self->userId or  $self->adminMode;
        }
        when ('resv'){
            my $adus = $dbh->selectrow_hashref('SELECT adus_id FROM adus WHERE adus_addr = ? AND adus_user = ?',{},$self->addrId,$self->userId);
            my $adusId = $adus->{adus_id};
            if ($self->adminMode and not $adus->{adus_id}){
                # insert admin permission as required
                $adusId = $self->putEntry('adus',undef,{
                    adus_addr => $self->addrId,
                    adus_user => $self->userId,
                    adus_admin => 1
                });
            }            
            $rec->{resr_adus} = $adusId;            
        }
        when ('acct'){
            die mkError(8744,"Only admin can enter booking records") unless $self->adminMode;
        }
        when ('adus'){
            my $adus = $dbh->selectrow_hashref('SELECT adus_admin FROM adus WHERE adus_addr = ? AND adus_user = ?',{},$self->addrId,$self->userId);
            die mkError(8344,"No permissions to edit adus table") 
                unless $self->adminMode or $adus->{adus_admin};
        }
        default {
            die mkError(3945,"Table $table not open for edit");
        }
    }
    if ($recId){
        
        $dbh->do(<<SQL_END);
SQL_END
    }
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

 2010-11-04 to 1.0 first version

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

