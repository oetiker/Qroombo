package QR::Database;
use strict;
use warnings;
use Data::Dumper;
use Time::Local;
use Encode;
use Mail::Sender;
use Digest;
use Carp;
use Mojo::JSON;

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
has log         => sub { croak "log handler is required" };

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

our $TABLES = {
    user => {
        fields => [qw(email first last phone extra addr)],
        conf => {
            email => {
                label => 'eMail',
                sql   => 'UNIQUE',
                access => {
                    admin => 'write',
                    user  => 'read'
                }
            },
            first => {
                label => 'First Name',
            },
            last => {
                label => 'Last Name',
            },
            phone => {
                label => 'Phone',
            },
            extra => {
                opt => 1
            },
            addr => {
                type => 'INTEGER',
                opt => 1
            }
        },
    },
    addr => {
        fields => [qw(org contact str zip town cntry extra)],
        conf => {
            org => {
                label => 'Organization',
                opt => 1,
            },
            contact => {
                label => 'Contact Name',
            },
            str => {
                label => 'Address',
            },
            zip => {
                label => 'Post Code',
            },
            town => {
                label => 'Town',
            },
            cntry => {
                label => 'Country',
                opt => 1
            },
            extra => {
                opt => 1
            }
        },
    },
    adus => {
        fields => [qw(addr user admin removed)],
        conf => {
            addr => {
                type => 'INTEGER',
                sql => 'REFERENCES user',
            },
            user => {
                type => 'INTEGER',
                sql => 'REFERENCES addr',
            },
            admin => {
                type => 'BOOL',
                sql => 'DEFAULT FALSE',
            },
            removed => {
                type => 'BOOL',
                sql => 'DEFAULT FALSE',
            }
        },
        sql => 'CONSTRAINT adus_unique UNIQUE(adus_addr,adus_user)'
    },
    resv => {
        fields => [qw(addr subj room start len pub price extra)],
        conf => {
            addr => {
                type => 'INTEGER',
                sql => 'NOT NULL REFERENCES addr',
            },  
            start => {
                type => 'NUMERIC',
            },  
            len => {
                type => 'NUMERIC',
            },
            pub => {
                type => 'BOOL',            
                label => 'Publish',
                widget => 'checkBox',
                opt => 1,
                set => {
                   label => 'Show Subject in Calendar'
                }
            },
            price => {
                type => 'NUMERIC',
                label => 'Price',
                access => {
                    admin => 'read',
                    user  => 'read'
                }
            },
            subj => {
                label => 'Subject'
            },  
            extra => {
                opt => 1
            },    
        },
    },
    acct => {
        fields => [ qw(addr date subj value resv) ],
        conf => {
            addr => {
                sql => 'REFERENCES addr',
                type => 'INTEGER',
            },
            date => {
                type => 'DATE',
            },
            value => {
                type => 'NUMERIC',
            },
            resv => {
                type => 'INTEGER',
                sql => 'REFERENCES resv'
            },                
        }
    },
    log => {
        fields => [ qw(date user subj old new) ],
        conf => {
            date=> {
                type => 'DATETIME'
            }
        }
    }  
};
# Make sure the tables required by Qroombo exist
sub _ensureTables {
    my $self = shift;
    my $dbh = $self->dbh;
    for my $tab (keys %$TABLES){
        my $def = $TABLES->{$tab};
        my @SQL = ${tab}.'_id INTEGER PRIMARY KEY AUTOINCREMENT';
        for my $field (@{$def->{fields}}){
            my $fdef = $def->{conf}{$field} or mkerror(38737,"Definition for $field not found in \%TABLES");
            push @SQL,
                $tab.'_'.$field . ' '
              . ( $fdef->{type} || 'TEXT' )
              . ( $fdef->{opt} ? '' : ' NOT NULL ' )
              . ( $fdef->{sql} || '' );
        }
        push @SQL, $def->{sql} if $def->{sql};
        $dbh->do("CREATE TABLE IF NOT EXISTS $tab ( ".join(",\n",@SQL)." )");
    }
    $dbh->do(<<SQL_END);
CREATE TRIGGER IF NOT EXISTS resv_insert_check 
BEFORE INSERT ON resv 
FOR EACH ROW WHEN
   EXISTS ( SELECT resv_id FROM resv
   WHERE new.resv_room = resv_room
     AND new.resv_start < resv_start + resv_len * 3600
     AND resv_start < new.resv_start + new.resv_len * 3600 )
BEGIN
   SELECT RAISE ( ABORT, 'can not insert overlapping reservations entries');
END
SQL_END
    $dbh->do(<<SQL_END);
CREATE TRIGGER IF NOT EXISTS resv_update_check 
BEFORE UPDATE OF resv_room,resv_start,resv_len ON resv 
FOR EACH ROW WHEN
   EXISTS ( SELECT resv_id FROM resv
    WHERE resv_id != new.resv_id
      AND new.resv_room = resv_room
      AND new.resv_start < resv_start + resv_len * 3600
      AND resv_start < new.resv_start + new.resv_len * 3600 )
BEGIN
   SELECT RAISE ( ABORT, 'this change would cause overlapping reservations entries');
END
SQL_END
}

sub new {
    my $self =  shift->SUPER::new(@_);
    $self->dbh($self->_connect());
    $self->_ensureTables();
    return $self;
}

=head2 getForm(table)

Return the form description for the given table

=cut

# Make sure the tables required by Qroombo exist
sub getForm {
    my $self = shift;
    my $table = shift;
    my $dbh = $self->dbh;
    my $tableDesc = $TABLES->{$table};
    my $cfg = $self->config->cfg;
    my @desc;
    my @fields = @{$tableDesc->{fields}};
    my $mode = $self->adminMode ? 'admin' : 'user';
    FIELD:
    for my $field (@fields){
        my $fdef = $tableDesc->{conf}{$field} || {}; 
        next unless $fdef->{label};
        $fdef->{set} ||= {};
        my @readOnly;
        if (my $ac = $fdef->{access}){
            given ($ac->{$mode}){
                when ('read'){
                    @readOnly = ( readOnly => Mojo::JSON->true, decorator => undef )
                }
                when ('none'){
                    next FIELD;
                }
            }
        }            
        push @desc, {
            key => $table.'_'.$field,
            label => $fdef->{label},
            widget => $fdef->{widget} || 'text',
            set => {
                required => $fdef->{opt} ? Mojo::JSON->false : Mojo::JSON->true,
                %{$fdef->{set}},
                @readOnly
            }
        }
    }
    my %cfgMap = (
        user => 'USER',
        addr => 'ADDRESS',
        resv => 'RESERVATION'    
    );
    if (my $cfgSection = $cfgMap{$table}){
        EXTRA:
        for my $extra (@{$self->_getExtraFields($cfgSection)}){
            if (my $ac = $extra->{access}){
                given ($ac->{$mode}){
                    when ('read'){
                        $extra->{set}{readOnly} = Mojo::JSON->true;
                        $extra->{set}{decorator} = undef;
                    }
                    when ('none'){
                        next EXTRA;
                    }
                }
            }
            if ($extra->{insertBefore}){
                for (my $i=0;$i<= $#desc;$i++){
                    if ($desc[$i]{key} ~~ $extra->{insertBefore}){
                        splice(@desc,$i,0,$extra);
                        next EXTRA;
                    }                    
                }
                $self->log->warn('Could not merge '.$extra->{key}.'. Since '.$extra->{insertBefore}.' was not found');
                push @desc,$extra;
            }
            else {
                push @desc,$extra;
            }
        };
    }
    return \@desc;
}


=head2 sendKey(email)

send a authentication key to the given email address

=cut

sub _mkKey {
    my $self = shift;
    my $text = lc shift;
    my $time = int( time / 3600 / 24); 
    my $dg = Digest->new('SHA-512');
    $dg->add($time,$text,$self->config->cfg->{GENERAL}{secret});
    my $key = $dg->b64digest;
    $key =~ s/[^2-9abcdefghjkmnpqrstuvwxyz]//gi;
    return sprintf('%s',lc(substr($key,1,5)));
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
    my $body = $cfg->{MAIL}{KEYMAIL}{body};
    my %map = (
        KEY => $key,
        TO => $email
    );
    my $pattern = join '|', keys %map;
    $body =~ s/{($pattern)}/$map{$1}/g;
    $sender->Open({ 
        %{$cfg->{MAIL}{KEYMAIL}{header}},
        to => $email,
        charset => 'UTF-8',
        encoding => 'Quoted-printable',
        ctype => 'text/plain',        
    });
    $sender->SendEnc($body);
    $sender->Close();
    my $user = $self->_getRawEntry('user','user_email',$email);
    return {
        eMail => $email,
        userId => $user->{user_id},
        userForm => $self->getForm('user'),
        addrForm => $self->getForm('addr')
    };
}


=head2 login(email,key,userData,addrData)

login the user, if he provides an email and a key
new users must provide additional information.

=cut

sub login {
    my $self = shift;
    my $email = lc shift;
    my $userKey = shift;
    my $userData = shift;
    my $addrData = shift;
    my $realKey = $self->_mkKey($email);
    die mkerror(3984,"not a valid key provided") unless $userKey ~~ $realKey;
    my $userRaw = $self->_getRawEntry('user','user_email',$email);
    my $userId =  $userRaw->{user_id};
    if (not $userId){
        $self->dbh->begin_work;
        eval {
            $self->adminMode(1); # get some extra privileges
            $userId = $self->putEntry('user',undef,{
                %$userData,
                user_email => $email
            });
            my $addrId = $self->putEntry('addr',undef,$addrData);
            $self->adminMode(1);
            $self->putEntry('adus',undef,{
                adus_addr => $addrId,
                adus_user => $userId,
                adus_admin => 1
            });
            $self->putEntry('user',$userId,{
                user_addr => $addrId
            });
        };
        if ($@){
            $self->dbh->rollback;
            die $@;
        }
        $self->dbh->commit;         
    }    
    return $userId;
}

=head2 getPrice(resv)

calculate the price for the given reservation

=cut

sub getPrice {
    my $self = shift;
    my $resv = shift;
    my $args = $self->_prepExtraArgs();
    my $roomCfg = $self->config->cfg->{ROOM};
    return $roomCfg->{PRICE_PL}->({
        %$args, 
        resv => $resv,
        room =>  $roomCfg->{info}{$resv->{resv_room}}{DATA_PL}->({ %$args, resv=> $resv })
    });            
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
    my $date = int(shift);
    my $dbh = $self->dbh;
    my $resArray = $dbh->selectall_arrayref(<<SQL_END,{ Slice => {}},$date);
SELECT
    resv_id,
    resv_room,
    resv_start,
    resv_len,
    resv_pub,
    resv_subj,
    resv_addr
  FROM resv
  WHERE resv_start < CAST(?1 AS INTEGER)  + 24 * 3600 AND 3600 * resv_len + resv_start > CAST(?1 AS INTEGER)
SQL_END
    my @ret;
    my $addrId = $self->addrId;
    for my $res (@$resArray){
        my $mine = $res->{resv_addr} ~~ $addrId;
        $res->{resv_subj} = ( $res->{resv_pub} or $mine ) ? $res->{resv_subj} : undef;
        push @ret, $res;
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
    return [] unless defined $value;
    my $dbh = $self->dbh;
    my $table = $dbh->quote_identifier($tableIn);
    my $column = $dbh->quote_identifier($columnIn);
    return $dbh->selectall_arrayref("SELECT * FROM $table WHERE $column = ?",{Slice=>{}},$value);
}

# just return the data without any checks
sub _getRawEntry {
    my $self = shift;
    my $data = $self->_getRawRows(@_);
    return ($data->[0] || {});
}

# create arguments to be supplied to the EXTRA_FIELDS_PL function
sub _prepExtraArgs {
    my $self = shift;
    my $args = {
        user => $self->_getRawEntry('user','user_id',$self->userId),
        addr => $self->_getRawEntry('addr','addr_id',$self->addrId),
        adminMode => $self->adminMode
    };
    for my $table (qw(user addr)){
        my $rec = $args->{$table};
        if ($rec->{$table.'_extra'}){
            my $extra = $self->json->decode($rec->{$table.'_extra'});
            delete $rec->{$table.'_extra'};
            map {$rec->{$_} = $extra->{$_}} keys %$extra;
        }
    }
    return $args;
}

sub _getExtraFields {
    my $self = shift;
    my $section = shift;
    my $cfg = $self->config->cfg;
    my $sub = $cfg->{$section}{EXTRA_FIELDS_PL};
    return ($sub ? $sub->($self->_prepExtraArgs) : [])
}

# remove extra fields from data hash and return a extra hash containing those
# that are available according to the access list
sub _extraFilter {
    my $self = shift;
    my $section = shift;
    my $data = shift;
    my $mode = shift || 'read';
    my $cfg = $self->config->cfg->{$section};
    my %ret;
    my $extraFields = $self->_getExtraFields($section);
    for my $field (@$extraFields){
        my $key = $field->{key};
        my $accessClass = $self->adminMode ? 'admin' : 'user';
        my $access = $field->{access}{$accessClass} || 'write';
        my $value = $data->{$key};
        delete $data->{$key};
        next if $access ~~ 'none';
        next if $mode ~~ 'write' and $access ~~ 'read';
        $ret{$key} = $value;
    }
    return \%ret;
}


# apply extra filter to an array of data
sub _arrayExtraFilter {
    my $self = shift;
    my $section = shift;
    my $table = shift;
    my $data = shift;
    for my $row (@$data){
        if ($row->{$table.'_extra'}){
            my $extra = $self->_extraFilter($section,$row);
            for my $key (keys %$extra) {
                $row->{$key} = $extra->{$key} 
            }
        }
        delete $row->{$table.'_extra'};
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
            if ( $self->adminMode 
                or $rec->{resv_addr} ~~ $self->addrId ){
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
            die mkerror(29344,"No permission to add reservation as no matching adus entry was found")
                if not $adusId and not $self->adminMode;
            $rec->{resv_addr} = $self->addrId;            
            $rec->{resv_price} = $self->getPrice($rec);
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
        my $sqlSet = 'SET '.join(", ", map {
            push @setValues, $rec->{$_};
            $dbh->quote_identifier($_)." = ?"
        } @keys);
        if ($extra){
            $sqlSet .= ", $extraQ = ?";
            push @setValues, $self->json->encode($extra);
        }
        my $count = $dbh->do(<<SQL_END,{},@setValues,$recId);
UPDATE $tableQ $sqlSet WHERE $recIdQ = ?
SQL_END
        if ($count != 1){
            die mkerror(3993,"wanted to update one record in $tableQ, succeded in updating $count");
        }
    }
    else {
        my @setValues;

        my $keys = join ", ", map {
            $dbh->quote_identifier($_)
        } @keys;
        my $placeholders = join ", ", map { '?' } @keys;
        my @values = map { $rec->{$_} } @keys;
            
        my $count = $dbh->do(<<SQL_END,{},@values,$extra);
INSERT INTO $tableQ ($keys) VALUES ( $placeholders )
SQL_END
        if ($count != 1){
            die mkerror(3993,"wanted to insert one record in $tableQ, succeded in inserting $count");
        }
        $recId = $dbh->last_insert_id("","","","");
    }
    return $recId;
}

=head2 removeEntry(table,id)

Remove the given entry from the table.

=cut

sub removeEntry {
    my $self = shift;
    my $table = shift;
    my $recId = shift;    
    my $dbh = $self->dbh;
    my $rec = $self->_getRawEntry($table,$table.'_id',$recId);   
    given ($table) {
        when ('addr'){                       
            my $adus = $dbh->selectrow_hashref('SELECT adus_id FROM adus WHERE adus_admin AND NOT adus_removed AND adus_addr = ? AND adus_user = ?',{},$recId,$self->userId);
            die mkerror(95334,"No premission to remove that address record")
                if not $adus->{adus_id} and not $self->adminMode;
        }
        when ('user'){
            die mkerror(38344,"No permission to remove user entry.")
                if  not $self->adminMode;
        }
        when ('resv'){
            die mkerror(38345,"No permission to remove reservation entry.")
                if not $rec->{resv_addr} ~~ $self->addrId and not $self->adminMode;
        }
        when ('acct'){
            die mkerror(8744,"No permission to remove accounting records.")
                if not $self->adminMode;
        }
        when ('adus'){
            my $adus = $dbh->selectrow_hashref('SELECT adus_admin FROM adus WHERE adus_addr = ? AND adus_user = ?',{},$self->addrId,$self->userId);
            die mkerror(8344,"No permissions to remove adus table entry") 
                if not $self->adminMode and not $adus->{adus_admin};
            $self->putEntry('adus',$recId,{ adus_removed => 1 });
        }
        default {
            die mkerror(3945,"Table $table not open removal calls");
        }
    }
    my $tableQ = $dbh->quote_identifier($table);          
    my $recIdQ = $dbh->quote_identifier($table.'_id');          
    my $ret;
    if ($recId){
        $ret = $dbh->do(<<SQL_END,{},$recId);
DELETE FROM $tableQ WHERE $recIdQ = ?
SQL_END
    }
    return $ret;    
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
  WHERE resv_addr = ?
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
            $self->_arrayExtraFilter('ADDRESS','addr',$data);
        }
        when ('user'){
            $data = $dbh->selectall_arrayref(<<SQL_END,{Slice=>{}},$self->adminMode ? 1 : 0,$self->userId,$limit,$offset);
SELECT *
  FROM user
  WHERE ? = 1 OR user_id = ?
  $ORDER
  LIMIT ? OFFSET ?
SQL_END
            $self->_arrayExtraFilter('USER','user',$data);
        }
        when ('resv'){
            $data = $dbh->selectall_arrayref(<<SQL_END,{Slice=>{}},$self->addrId,$limit,$offset);
SELECT resv_id, resv_room, datetime(resv_start) as resv_start, resv_len,resv_price,resv_subj,resv_extra
  FROM resv
  WHERE resv_addr = ?
  $ORDER
  LIMIT ? OFFSET ?
SQL_END
            $self->_arrayExtraFilter('RESERVATION','resv',$data);
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

