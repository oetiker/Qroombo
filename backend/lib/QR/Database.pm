package QR::Database;
use strict;
use warnings;
use Data::Dumper;
use Time::Local;
use Encode;
use Mail::Sender;

=head1 NAME

QR::Database - qroombo database

=head1 SYNOPSIS

 use QR::Database;

 my $db = QR::Database->new(
        config => $cfg
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
use POSIX qw(strftime);

my %tableNames = ( user =>1, addr=>1, adus=>1, resv=>1, acct=>1);

=head2 ATTRIBUTES

The cache objects have the following attributes

=cut

=head3 userId

the name of the current user. Some functions are also available if
no user is set.

=cut

has 'userId';

=head3 addrId

the current billing address.

=cut

has 'addrId';

=head3 adminMode;

are we running in admin mode ?

=cut

has adminMode => 0;

=head3 cfg

points to the config hash

=cut

has config  => sub { croak "The configuration object is required" };

=head3 dbh

the handle to the SQLite db

=cut

has 'dbh';

has encodeUtf8  => sub { find_encoding('utf8') };
has json        => sub { Mojo::JSON->new };


=head2 B<new>(I<config>)

Create an QR::Database object.

=over

=item B<cfg>

A hash pointer to the configuration as read by L<QR::Config>.

=back

=cut

# connect to the database
sub _connect {
    my $self = shift;
    my $path = $self->config->cfg->{GENERAL}{database_dir}.'/qroombo.sqlite';
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
user_first  TEXT NOT NULL,
user_last   TEXT NOT NULL,
user_phone1 TEXT,
user_phone2 TEXT,
user_extra  TEXT,
user_addr   INTEGER
SQL_END
        addr => <<SQL_END,
addr_id     INTEGER PRIMARY KEY AUTOINCREMENT,
addr_first  TEXT NOT NULL,
addr_last   TEXT NOT NULL,
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

=head2 sendKey(email)

send a authentication key to the given email address

=cut

sub _mkKey {
    my $self = shift;
    my $text = lc shift;
    my $time = int( time / 3600 / 24); 
    my $dg = Digest->new('MD5');
    $dg->add($time,$text,$self->config->cfg->{GENERAL}{secret});
    return sprintf('%s',lc(substr($dg->hexdigest,1,6)));
}

sub sendKey {
    my $self = shift;   
    my $email = lc shift;
    my $cfg = $self->config->cfg;
    die mkerror(18473,"expected an email adddress")
       if $email !~ m/^[^\s\@]+\@[^\s\@]+$/;
    my $key = $self->_mkKey($email); 
    my $sender = new Mail::Sender({
        smtp => $cfg->{MAIL}{smtp_server},
        from => $cfg->{MAIL}{sender},
        on_errors => 'die' 
    });
    $sender->Open({
        to => $email,
        charset => 'UTF-8',
        encoding => 'Quoted-printable',
        ctype => 'text/plain',
    });
    my $body = $cfg->{MAIL}{KEYMAIL}{body};
    my %map = {
        KEY => $key,
        TO => $email
    };
    my $pattern = join '|', keys %map;
    $body =~ s/{($pattern)}/$map{$1}/g;
    my $header = $cfg->{MAIL}{KEYMAIL}{header};
    $header->{to} = $email;
    $sender->Open($header);
    $sender->SendEnc($body);
    $sender->Close();
    my $user = $self->_getRawEntry('user','user_email',$email);
    return { userId => $user->{user_id} }
}


=head2 login(email,key,userData)

login the user, if he provides an email and a key
new users must provide additional information.

=cut

sub login {
    my $self = shift;
    my $email = lc shift;
    my $userKey = shift;
    my $data = shift;
    my $realKey = $self->_mkKey($email);
    die mkerror(3984,"not a valid key provided") unless $userKey ~~ $realKey;
    my $userRaw = $self->_getRawEntry('user','user_email',$email);
    my $userId =  $userRaw->{user_id};
    if (not $userId){
        $userId = $self->putEntry('user',undef,{
            user_email => $email,
            map { $data->{$_} ? ( $_ => $data->{$_} ) : () } 
                qw(user_first user_last user_phone1)
        });
        $data->{addr_first} = $data->{user_first},
        $data->{addr_last} = $data->{user_last},
        my $addrId = $self->putEntry('addr',undef,{
            map { $data->{$_} ? ( $_ => $data->{$_} ) : () } 
                qw(addr_first addr_last addr_org addr_addr1 addr_addr2 addr_zip addr_town addr_cntry)
        });
        $self->putEntry('adus',undef,{
            adus_addr => $addrId,
            adus_user => $userId,
            adus_admin => 1
        });
                
    }

    return $userId;
}

=head2 setAddrId(id)

Activate the given address id for the user

=cut

sub setAddrId {
    my $self = shift;
    my $addrId = shift;
    if (not $self->adminMode){
        my $row = $self->dbh->selectrow_hashref(<<SQL_END,{},$self->userId,$addrId);
SELECT addr_id
  FROM addr
  JOIN adus ON addr_id = adus_addr
 WHERE adus_user = ? AND addr_id = ?
SQL_END
        mkerror(9384,"No permission to set AddressId $addrId")
            if not $row->{addr_id} ~~ $addrId;            
    }
    $self->putEntry('user',$self->userId,{
        user_addr => $addrId
    });
    return $addrId;
}

=head2 getCalendarDay(date)

Returns the list of reservations for the given day (UTC). The date is to be given in unix epoch seconds.

=cut

sub getCalendarDay {
    my $self = shift;
    my $date = strftime('%Y-%m-%d',gmtime(shift));
    my $dbh = $self->dbh;
    my $resArray = $dbh->selectall_arrayref(<<SQL_END,{ Slice => {}},$date);
SELECT resv_id,
       resv_room,
       date(resv_start,'utc') AS date,
       strftime('%H',resv_start,'utc') AS start,
       resv_len,
       resv_pub,
       resv_subj,
       adus_addr
  FROM resv 
  JOIN adus ON (resv_adus = adus_id)  
  WHERE date(resv_start,'utc') = ?
SQL_END
    my @ret;
    my $addrId = $self->addrId;
    for my $res (@$resArray){
        my $mine = $res->{adus_addr} ~~ $addrId;
        push @ret, {
            resvId => $res->{resv_id},
            roomId => $res->{resv_room},
            startDate => $res->{date},
            startHr => $res->{start},
            duration => $res->{resv_len},
            subject => ( $res->{resv_pub} or $mine ) ? $res->{resv_subj} : undef,
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
sub _getRawRows {
    my $self = shift;
    my $tableIn = shift;
    my $columnIn = shift;
    my $value = shift;
    my $dbh = $self->dbh;
    my $table = $dbh->quote_identifier($tableIn);
    my $column = $dbh->quote_identifier($columnIn);
    return $dbh->selectall_arrayref("SELECT * FROM $table WHERE $column = ?",{Slice=>{}},$value);
}

# just return the data without any checks
sub _getRawEntry {
    my $self = shift;
    return ($self->_getRawRows(@_))[0];
}

# remove extra fields from data hash and return a extra hash containing those
# that are available according to the access list
sub _extraFilter {
    my $self = shift;
    my $section = shift;
    my $data = shift;
    my $mode = shift // 'read';
    my $cfg = $self->config->cfg->{$section};
    my %ret;
    if ($cfg->{EXTRA_FIELDS_PL}){
        my $extraFields = $cfg->{EXTRA_FIELDS_PL}();
        for my $field (@$extraFields){
            my $key = $field->{key};
            my $accessClass = $self->adminMode ? 'admin' : 'user';
            my $access = $field->{access}{$accessClass} // 'write';
            my $value = $data->{$key};
            delete $data->{$key};
            next if $access ~~ 'none';
            next if $mode ~~ 'write' and $access ~~ 'read';
            $ret{$key} = $value;
        }
    }
    return \%ret;
}

# apply extra filter to an array of data
sub _arrayExtraFilter {
    my $self = shift;
    my $section = shift;
    my $data = shift;
    for my $row (@$data){
        my $extra = $self->_extraFilter('ADDRESS',$row);
        for my $key (keys %$extra) {
            $row->{$key} = $extra->{$key} 
        }
    }
}


sub getEntry {
    my $self = shift;
    my $table = shift;
    my $recId = shift;
    my $dbh = $self->dbh;
    my $rec = $self->_getRawEntry($table,$table.'_id',$recId);   
    my $extra = {};
    if ($rec->{$table.'_extra'}){
        $extra = $self->json->decode($rec->{$table.'_extra'});        
        delete $rec->{$table.'_extra'};
    }
    my $cfg= $self->config->cfg;
    given ( $table ) {
        when ('addr') {
            my $adus = $dbh->selectrow_hashref('SELECT adus_id FROM adus WHERE adus_addr = ? AND adus_user = ?',{},$recId,$self->userId); 
            if ($self->adminMode or $adus->{adus_id}){
                my $users = $dbh->selectcol_arrayref(<<SQL_END,{Columns=>[1,2,3]},$recId);
SELECT user_email,adus_id,adus_admin
  FROM adus
  JOIN user ON ( adus_user = user_id )
 WHERE adus_addr = ?
SQL_END
                $extra = $self->_extraFilter('ADDRESS',$extra);
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
                $extra = $self->_extraFilter('USER',$extra);
                return { %$extra, %$rec};
            }
        }
        when ('resv'){
            my $adus = $self->_getRawEntry('adus','adus_id',$rec->{resv_adus});
            if ( $self->adminMode 
                or $adus->{adus_user} ~~ $self->userId 
                or $adus->{adus_addr} ~~ $self->addrId ){
                $extra = $self->_extraFilter('RESERVATION',$extra);
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
    die mkerror(39934,'Record acccess permission denied');
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
    my $dbh = $self->dbh;
    # can't change or set the id of a record
    delete $rec->{$table.'_id'};
    my $extra;
    given ($table) {
        when ('addr'){                       
            my $adus = $dbh->selectrow_hashref('SELECT adus_id FROM adus WHERE adus_admin AND adus_addr = ? AND adus_user = ?',{},$recId,$self->userId);
            die mkerror(95334,"No premission to edit address record")
                unless $adus->{adus_id} or not $recId or $self->adminMode;
            $extra = $self->_extraFilter('ADDRESS',$rec,'write');
        }
        when ('user'){
            die mkerror(38344,"No permission to edit user details")
                unless not $recId or $recId ~~ $self->userId or  $self->adminMode;
            $extra = $self->_extraFilter('USRE',$rec,'write');
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
            $extra = $self->_extraFilter('RESERVATION',$rec,'write');
        }
        when ('acct'){
            die mkerror(8744,"Only admin can enter booking records") unless $self->adminMode;
        }
        when ('adus'){
            my $adus = $dbh->selectrow_hashref('SELECT adus_admin FROM adus WHERE adus_addr = ? AND adus_user = ?',{},$self->addrId,$self->userId);
            die mkerror(8344,"No permissions to edit adus table") 
                unless $self->adminMode or $adus->{adus_admin};
        }
        default {
            die mkerror(3945,"Table $table not open for edit");
        }
    }
    my $tableQ = $dbh->quote_identifier($table);          
    my $recIdQ = $dbh->quote_identifier($table.'_id');          
    my $extraQ = $dbh->quote_identifier($table.'_extra');          
    my @keys = sort keys %$rec;
    if ($recId){
        my @setValues;
        my $sqlSet = join ", ", map {
            push @setValues, $rec->{$_};
            "SET ".$dbh->quote_identifier($_)." = ?"
        } @keys;
        if ($extra){
            $sqlSet .= ", $extraQ = ?";
            push @setValues, $self->json->encode($extra);
        }
        $dbh->do(<<SQL_END,{},@setValues,$recId);
UPDATE $tableQ $sqlSet WHERE $recIdQ = ?
SQL_END
    }
    else {
        my @setValues;

        my $keys = join ", ", map {
            $dbh->quote_identifier($_)
        } @keys;
        my $placeholders = join ", ", map { '?' } @keys;
        my @values = map { $rec->{$_} } @keys;
            
        $dbh->do(<<SQL_END,{},@values,$extra);
INSERT INTO $tableQ ($keys) VALUES ( $placeholders )
SQL_END
        $recId = $dbh->last_insert_id("","","","");
    }
    return $recId;
}

=head2 getRowCount(table)

Return the number of rows matching the given filter.

=cut

sub getRowCount {
    my $self = shift;
    my $table = shift;
    my $dbh = $self->dbh;
    given($table){
        when ('addr'){
            return ($dbh->selectrow_array(<<SQL_END,{},$self->adminMode ? 1 : 0,$self->userId))[0];
SELECT COUNT(*)
  FROM addr
  WHERE ? = 1 OR addr_id IN ( SELECT adus_addr FROM adus WHERE adus_user = ? )
SQL_END
        }
        when ('user'){
            return ($dbh->selectrow_array(<<SQL_END,{},$self->adminMode ? 1 : 0,$self->userId))[0];
SELECT COUNT(*)
  FROM user
  WHERE ? = 1 OR user_id = ?
SQL_END
        }
        when ('resv'){
            return ($dbh->selectrow_array(<<SQL_END,{},$self->addrId))[0];
SELECT COUNT(*)
  FROM resv
  JOIN adus ON ( resv_adus = adus_id )
  WHERE adus_addr = ?
SQL_END
        }
        when ('acct'){
            return ($dbh->selectrow_array(<<SQL_END,{},$self->addrId))[0];
SELECT COUNT(*)
  FROM acct
  WHERE acct_addr = ?
SQL_END
        }
        default {
            die mkerror(3884,"Table '$table' is not valid");
        }
    }
    return 0;
}

=head2 getRows(table,limit,offset,sort-col,desc?)

Returns the chosen number of rows from the table.

=cut

sub getRows {
    my $self = shift;
    my $dbh = $self->dbh;
    my $table = shift;
    my $limit = shift;
    my $offset = shift;
    my $sortCol = shift;
    my $desc = (shift) ? 'DESC' : 'ASC';
    my $ORDER ='';
    if ($sortCol){
       $ORDER = 'ORDER BY '.$dbh->quota_identifier($sortCol).' '.$desc;
    }
    my $data;
    given($table){
        when ('addr'){
            $data = $dbh->selectall_arrayref(<<SQL_END,{Slice=>{}},$self->adminMode ? 1 : 0,$self->userId,$limit,$offset);
SELECT *
  FROM addr
  WHERE ? = 1 OR addr_id IN ( SELECT adus_addr FROM adus WHERE adus_user = ? )
  $ORDER
  LIMIT ? OFFSET ?
SQL_END
            $self->_arrayExtraFilter('ADDRESS',$data);
        }
        when ('user'){
            $data = $dbh->selectall_arrayref(<<SQL_END,{Slice=>{}},$self->adminMode ? 1 : 0,$self->userId,$limit,$offset);
SELECT *
  FROM user
  WHERE ? = 1 OR user_id = ?
  $ORDER
  LIMIT ? OFFSET ?
SQL_END
            $self->_arrayExtraFilter('USER',$data);
        }
        when ('resv'){
            $data = $dbh->selectall_arrayref(<<SQL_END,{Slice=>{}},$self->addrId,$limit,$offset);
SELECT resv_id, resv_room, resv_start,resv_len,resv_price,resv_subj,resv_extra,user_email
  FROM resv
  JOIN adus ON ( resv_adus = adus_id )
  JOIN user ON ( adus_user = user_id )
  WHERE resv_addr = ?
  $ORDER
  LIMIT ? OFFSET ?
SQL_END
            $self->_arrayExtraFilter('RESERVATION',$data);
        }
        when ('acct'){
            $data = $dbh->selectall_arrayref(<<SQL_END,{Slice=>{}},$self->addrId,$limit,$offset);
SELECT *
  FROM acct
  WHERE acct_addr = ?
  $ORDER
  LIMIT ? OFFSET ?
SQL_END
        }
        default {
            die mkerror(4924,"Table '$table' is not valid");
        }
    }
    return $data;    
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

