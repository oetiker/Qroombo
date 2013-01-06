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

# turn k => [ x => y, ... ] into k=>{x=>y,...},k_order=>[qw(x ...)]

sub _reArrange {
    my $data = shift;
    for my $table (keys %$data) {
        my $t = $data->{$table};
        for my $key ( keys %$t ) {
            my $k = $t->{$key};
            if (ref $k eq 'ARRAY'){
                $t->{$key} = {};
                while (@$k) {
                    my $field = shift @$k;
                    $t->{$key}{$field} = shift @$k;
                    push @{$t->{${key}."_order"}}, $field;
                }                
            }
        }
        # supply default values for labels
        if ($t->{tabView}){
            for my $key ( keys $t->{fields} ){
                next unless $t->{tabView}{$table.'_'.$key};
                $t->{tabView}{$table.'_'.$key}{label} ||= $t->{fields}{$key}{label};
            }
        }
    }
    return $data;
}

our $TABLES = _reArrange {
    user => {
        tabView => [
            user_id => {
                label => 'ID',
                width => 2,
                format => 'number'
            },
            user_first => {
                width => 3
            },
            user_last => {
                width => 3
            },
            user_phone => {
                width => 3
            }
        ],
        fields => [
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
                dbOpt => 1
            },
            last => {
                label => 'Last Name',
                dbOpt => 1
            },
            phone => {
                label => 'Phone',
                opt => 1
            },
            extra => {
                opt => 1
            },
            addr => {
                type => 'INTEGER',
                opt => 1,
                sql => 'REFERENCES addr',
            }
        ]
    },
    addr => {
        tabView => [
            addr_id => {
                label => 'ID',
                width => 2,
                format => 'number',                
            },
            addr_contact => {
                label => 'Contact',
                width => 4,
            },
            addr_org => {
                label => 'Organization',
                width => 4
            },
            balance => {
                label => 'Balance',
                width => 5,
            },
        ],
        fields => [
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
                opt => 1,
            },
            user => {
                label => 'Users',
                virtual => 1,
                opt => 1,
                skipNew => 1,
            },
            admin => {
                label => 'Admin Users',
                virtual => 1,
                opt => 1,
                skipNew => 1,
            },
            extra => {
                opt => 1
            },
        ],
    },
    adus => {
        fields => [
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
        ],
        sql => 'CONSTRAINT adus_unique UNIQUE(adus_addr,adus_user)'
    },
    resv => {
        tabView => [
            resv_id => {
                label => 'ID',
                width => 1,
                format => 'number'
            },
            resv_room => {
                width => 3,
                label => 'Room'
            },
            day => {
                label => 'Date',
                width => 1
            },
            start => {
                label => 'Start',
                width => 1
            },
            end => {
                label => 'End',
                width => 1
            },
            resv_price => {
                width => 1,
            },
            resv_subj => {
                width => 5
            },
        ],
        fields => [
            addr => {
                type => 'INTEGER',
                sql => 'NOT NULL REFERENCES addr',
            },  
            room => {
                label => 'Room',
                widget => 'selectBoxRooms',
            },
            start => {
                type => 'NUMERIC',
            },  
            len => {
                type => 'NUMERIC',
            },
            date => {
                label => 'Date',
                widget => 'date',
                virtual => 1
            },
            begin => {
                label => 'Start',
                widget => 'time',
                virtual => 1
            },
            end => {
                label => 'End',
                widget => 'time',
                virtual => 1
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
        ],
    },
    acct => {
        tabView => [
            acct_id => {
                label => 'ID',
                width => 1,
            },
            date => {
                label => 'Date',
                width => 2,
            },            
            acct_subj => {
                width => 2,
            },
            acct_value => {
                width => 1,
            },                
        ],
        fields => [
            addr => {
                sql => 'REFERENCES addr',
                type => 'INTEGER',
            },
            subj => {
                label => 'Subject',
            },
            date => {
                type => 'DATE',
                label => 'Date',
            },
            value => {
                type => 'NUMERIC',
                label => 'Value'
            },
            resv => {
                type => 'INTEGER',
                sql => 'REFERENCES resv',
                opt => 1
            },                
        ]
    },
    log => {
        fields => [
            date=> {
                type => 'DATETIME'
            },
            user => {},
            subj => {},
            old => {},
            new => {}
        ]
    }  
};

# Make sure the tables required by Qroombo exist
sub _ensureTables {
    my $self = shift;
    my $dbh = $self->dbh;
    for my $tab (keys %$TABLES){
        my $def = $TABLES->{$tab};
        my @SQL = ${tab}.'_id INTEGER PRIMARY KEY AUTOINCREMENT';
        for my $field (@{$def->{fields_order}}){
            my $fdef = $def->{fields}{$field} or mkerror(38737,"Definition for $field not found in \%TABLES");
            next if $def->{fields}{$field}{virtual};
            push @SQL,
                $tab.'_'.$field . ' '
              . ( $fdef->{type} || 'TEXT' )
              . ( $fdef->{opt} or $fdef->{dbOpt} ? '' : ' NOT NULL ' )
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

=head2 getForm(table,skipNew?)

Return the form description for the given table. Ignore items with skipNew if option set.

=cut

# Make sure the tables required by Qroombo exist
sub getForm {
    my $self = shift;
    my $table = shift;
    my $skipNew = shift;
    my $tableDesc = $TABLES->{$table};
    my $cfg = $self->config->cfg;
    my @desc;
    my @fields = @{$tableDesc->{fields_order}};
    my $mode = $self->adminMode ? 'admin' : 'user';
    FIELD:
    for my $field (@fields){
        my $fdef = $tableDesc->{fields}{$field} || {};         
        next unless $fdef->{label};
        next if $skipNew and $fdef->{skipNew};
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

# Make sure the tables required by Qroombo exist
sub getTableView {
    my $self = shift;
    my $table = shift;
    my $tableDesc = $TABLES->{$table};
    my $cfg = $self->config->cfg;
    my @desc;
    my @fields = @{$tableDesc->{tabView_order}};
    my @tabFields;
    my @tabLabels;
    my @tabWidths;
    my $mode = $self->adminMode ? 'admin' : 'user';
    FIELD:
    for my $field (@fields){
        my $fdef = $tableDesc->{tabView}{$field} || {};         
        next unless $fdef->{label};
        $fdef->{set} ||= {};
        my @readOnly;
        if (my $ac = $fdef->{access}){
            given ($ac->{$mode}){
                when ('none'){
                    next FIELD;
                }
            }
        }            
        push @tabFields, $field;
        push @tabWidths, $fdef->{width} // 1;
        push @tabLabels, $fdef->{label} // $field;
    }
    my %cfgMap = (
        user => 'USER',
        addr => 'ADDRESS',
        resv => 'RESERVATION'    
    );
    if (my $cfgSection = $cfgMap{$table}){
        EXTRA:
        for my $extra (@{$self->_getExtraFields($cfgSection)}){
            my $pos = $extra->{tabViewPos};
            next unless defined $pos;
            if (my $ac = $extra->{access}){
                given ($ac->{$mode}){
                    when ('none'){
                        next;   
                    }
                }
            }            
            splice(@tabFields,$pos,0,$extra->{key});
            splice(@tabWidths,$pos,0,$extra->{tabViewWidth} // 1);
            splice(@tabLabels,$pos,0,$extra->{label});
        };
    }

    return {
        fields => \@tabFields,
        widths => \@tabWidths,
        labels => \@tabLabels,
    }
}

=head2 sendKey(email)

send a authentication key to the given email address. 

=cut

sub _mkKey {
    my $self = shift;
    my $text = lc shift;
    my $shift = shift || 0; # shift time by x periodes
    my $time = int( time / 3600 / 24) - $shift; 
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
        addrForm => $self->getForm('addr',1)
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
    my $prevRealKey = $self->_mkKey($email,1);
    die mkerror(3984,"not a valid key provided") unless $userKey ~~ $realKey or $userKey ~~ $prevRealKey;
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
    $self->_normalizeResv($resv);
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
                my $users = $dbh->selectall_arratref(<<SQL_END,{Slice=>{}},$recId);
SELECT user_email,adus_admin
  FROM adus
  JOIN user ON ( adus_user = user_id )
 WHERE adus_addr = ?
SQL_END
                my @userList;
                my @adminList;
                for my $u (@$users){
                    if ($u->{adus_admin}){
                        push @adminList, $u->{user_email}
                    }
                    else {
                        push @userList, $u->{user_email}
                    }
                }            
                $extra = $self->_extraFilter('ADDRESS',$extra);
                
                return {
                    %$extra,                    
                    %$rec,
                    adus_admin => join ',',@adminList,
                    adus_user => join ',',@userList,
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
                $rec->{resv_date} = timegm(0,0,0,(gmtime($rec->{resv_start}))[3,4,5]);
                $rec->{resv_begin} = (gmtime($rec->{resv_start}))[2];
                $rec->{resv_end} = ($rec->{resv_begin} + $rec->{resv_len}).':00';
                $rec->{resv_begin} .= ':00';
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

=head2 getUserId(email,create?)

figure the userId for an email address. If the create option is set, create a new user entry for the email address.

=cut

sub getUserId {
    my $self = shift;
    my $email = shift;
    my $create = shift;
    my $dbh = $self->dbh;
    my $user = $self->_getRawEntry('user','user_email',$email);
    my $userId = $user->{user_id} or $self->putEntry('user',undef,{user_email => $email});
    return $userId;
}

=head2 getAdusMap(addrId)

get the adus records for the given address, keyed by email address

=cut

sub getAdusMap {
    my $self = shift;
    my $addrId = shift;
    my $dbh = $self->dbh;
    return  $dbh->selectall_hashref('SELECT user_email,* FROM adus JOIN user ON adus_user = user_id WHERE adus_addr = ?','user_email',{Slice=>{}},$addrId);
}    

=head2 _normalizeResv(rec)

normalize a reservation record

=cut

sub _normalizeResv {
    my $self = shift;
    my $rec = shift;

    return if not $rec->{resv_date};

    my $resvCfg = $self->config->cfg->{RESERVATION};

    my $begin = int((split ':', $rec->{resv_begin})[0]);
    die mkerror(23133,"Begin must at or after $resvCfg->{first_hour}:00") 
        if $begin < $resvCfg->{first_hour};

    my $end = int((split ':', $rec->{resv_end})[0]);
    $end = 24 
        if $end == 0;
    die mkerror(23134,"End must at or before ".($resvCfg->{last_hour}+1).":00") 
        if $end > $resvCfg->{last_hour};
     die mkerror(23134,"The Beginning must be befor the End of your Reservation") 
        if $begin >= $end;
     $rec->{resv_start} = $rec->{resv_date} + $begin * 3600;
    $rec->{resv_len} = int($end - $begin);
    delete $rec->{resv_date};
    delete $rec->{resv_begin};
    delete $rec->{resv_end};
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
            my $existingRec = $recId ? $self->getEntry($table,$recId) : {};
            $rec = { %$existingRec, %$rec };
            $rec->{resv_addr} = $self->addrId;
            $self->_normalizeResv($rec);
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
    if ($table eq 'addr'){
        my $adus = $self->getAdusMap($recId);
        if ($rec->{addr_user}){
            for my $entry ( split /[;,\s]/, $rec->{addr_user} ) { #]]
                my $rec = $adus->{$entry};
                $adus->{$entry}{acted} = 1;
                next if $rec and not $rec->{adus_admin};
                my $userId = $rec ? $rec->{user_id} : $self->getUserId($entry,1);
                $self->putEntry('adus',$rec ? $rec->{adus_id} : undef,{adus_user => $userId, adus_admin => 0});
            }
            delete $rec->{addr_user};
        }
        if ($rec->{addr_admin}){
            for my $entry ( split /[;,\s]/, $rec->{addr_admin} ) { # ]]
                my $rec = $adus->{$entry};
                $adus->{$entry}{acted} = 1;
                next if $rec and not $rec->{adus_admin};
                my $userId = $rec ? $rec->{user_id} : $self->getUserId($entry,1);
                $self->putEntry('adus',$rec ? $rec->{adus_id} : undef,{adus_user => $userId, adus_admin => 1});
            }
            delete $rec->{addr_admin};
        }
        for my $key (keys %$adus){
            next if $adus->{$key}{acted};
            $self->removeEntry('adus',$adus->{$key}{adus_id});
        }
    }
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
        my $count = eval {
            $dbh->do(<<SQL_END,{},@setValues,$recId);
UPDATE $tableQ $sqlSet WHERE $recIdQ = ?
SQL_END
        };

        if ($@){
            if ($@ =~ /overlap/){
                die mkerror(58224,"Can't perform the update as your new entry would overlap with an existing one");
            }
            die $@;
        }

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
    my $search = shift;
    my $limit = shift;
    my $offset = shift;
    my $sortCol = shift;
    my $desc = (shift) ? 'DESC' : 'ASC';
    my $ORDER ='';
    if ($sortCol){
       $ORDER = 'ORDER BY '.$dbh->quote_identifier($sortCol).' '.$desc;
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
  WHERE 1 = ? OR user_id = ?
  $ORDER
  LIMIT ? OFFSET ?
SQL_END
            $self->_arrayExtraFilter('USER','user',$data);
        }
        when ('resv'){
            $data = $dbh->selectall_arrayref(<<SQL_END,{Slice=>{}},$self->addrId,$limit,$offset);
SELECT resv_id, resv_room, resv_start, resv_len,resv_price,resv_subj,resv_extra,
       date(resv_start,'unixepoch') as day,
       time(resv_start,'unixepoch') as start,
       time(resv_start + resv_len * 3600-1, 'unixepoch') as end
  FROM resv
  WHERE resv_addr = ?
  $ORDER
  LIMIT ? OFFSET ?
SQL_END
            $self->_arrayExtraFilter('RESERVATION','resv',$data);
        }
        when ('acct'){
            $data = $dbh->selectall_arrayref(<<SQL_END,{Slice=>{}},$self->addrId,$limit,$offset);
SELECT *,
        date(acct_date,'unixepoch') as date
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

