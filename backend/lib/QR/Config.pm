package QR::Config;
use strict;  
use warnings;

=head1 NAME

QR::Config - The Qroombo File

=head1 SYNOPSIS

 use QR::Config;

 my $c = QR::Config->new(file=>'/etc/extopus/system.cfg');

 $c->reload_config();
 $c->make_pod();
 my $cfg = $c->cfg;

=head1 DESCRIPTION

Configuration reader for Extopus

=cut

use Carp;
use Config::Grammar;
use Mojo::Base -base;
use Encode;
use POSIX qw(strftime);

=head2 ATTRIBUTES

=head3 file

the path to the config file

=cut

has 'file';

=head3 cfg

pointing to the map with the data from the config file.

=cut

has 'cfg';

=head2 METHODS

All methods inherited from L<Mojo::Base>. As well as the following:

=cut

=head2 QR::Config->new(file=>'config/file')

Instanciate the config object and load the config file.

=cut

sub new {
    my $self =  shift->SUPER::new(@_);
    $self->reloadConfig();
    return $self;
}

=head2 $x->B<reloadConfig>

Read the configuration file and die if there is a problem.

=cut

sub reloadConfig {
    my $self = shift;
    my $parser = $self->_make_parser();
    my $cfg = $parser->parse($self->file) or croak($parser->{err});
    my @roomList;
    for my $section (keys %$cfg){
        # list compiled code sections up
        next unless ref $cfg->{$section} ~~ 'HASH';
        my $sec = $cfg->{$section};
        for my $key (keys %{$cfg->{$section}}){
            next unless $key =~ /_PL$/ and $sec->{$key}{_text};
            $sec->{$key} = $sec->{$key}{_text};
        }
        # mode per room configs into the ROOM key
        if ($section =~ /^ROOM:\s*(\S+)/){
            $roomList[$sec->{_order}] = $1;
            delete $sec->{_order};
            $cfg->{ROOM}{info}{$1} = $sec;
            delete $cfg->{$section};
        }
    }
    $cfg->{ROOM}{list} = \@roomList;
    my ($header,$body) = split /\r?\n\s*\r?\n/, $cfg->{MAIL}{KEYMAIL}{_text};
    my @header = split /\r?\n(?=\S)/, $header;
    my %header;
    for (@header){
        s/^From:\s+//i && do {
            $header{fake_from} = $_;
            next;
        };
        s/^Subject:\s+//i && do {
            $header{subject} = encode('MIME-Header',$_);
            next;
        };
        s/^Cc:\s+//i && do {
            $header{cc} = $_;
            next;
        };
        s/^Bcc:\s+//i && do {
            $header{bcc} = $_;
            next;
        };
        die "ERROR: Invalid KEYMAIL Header: $_\n";
    }
    $cfg->{MAIL}{KEYMAIL} = {
        header => \%header,
        body => $body
    };    
    $self->cfg($cfg);    
}

=head2 $x->B<make_config_pod>()

Create a pod documentation file based on the information from all config actions.

=cut

sub make_pod {
    my $self = shift;
    my $parser = $self->_make_parser();
    my $E = '=';
    my $footer = <<"FOOTER";

${E}head1 COPYRIGHT

Copyright (c) 2011 by OETIKER+PARTNER AG. All rights reserved.

${E}head1 LICENSE

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

${E}head1 AUTHOR

S<Tobias Oetiker E<lt>tobi\@oetiker.chE<gt>>

${E}head1 HISTORY

 2011-04-19 to 1.0 first version

FOOTER
    my $header = $self->_make_pod_header();    
    return $header.$parser->makepod().$footer;
}



=head2 $x->B<_make_pod_header>()

Returns the header of the cfg pod file.

=cut

sub _make_pod_header {
    my $self = shift;
    my $E = '=';
    return <<"HEADER";
${E}head1 NAME

qroombo.cfg - The Qroombo configuration file

${E}head1 SYNOPSIS

 *** GENERAL ****
 admin = admin\@example.com cro\@example.com
 secret = very_secret_cookie_secret
 log_file = /tmp/qroombo.log
 log_level = debug
 database_dir = /tmp/qroombo
 title = Flörli Olten

 *** MAIL ***
 smtp_server = smtp.example.com
 sender = resv\@example.com

 *** RESERVATION ***
 first_hour = 7
 last_hour = 23

 +EXTRA_FIELDS_PL
 [
  {
    key => 'horytarif',
    label => 'Horyzon Tarif',
    widget => 'checkBox',
    set => {
        label => '+1 CHF pro Mietstunde zu Gunsten von Horyzon',        
    }
  },
  {
    key => 'tarif',
    label => 'Tarif',
    widget => 'selectBox',
  }
 ]

 return {
     tarif => \$ret
 };

 *** USER ***
 +EXTRA_FIELDS_PL
 
 *** ADDRESS ***

 +EXTRA_FIELDS_PL
 [  
  {
    key => 'allow_free',
    label => 'Gratis',
    widget => 'checkBox',
    set => {
        label => 'Gratis Miete erlauben',
    },
    access => {
        admin => 'write',
        user => 'read',
    }
  }
 ]

 *** ROOM ***
 +PRICE_PL
 if (\$D{address}{allow_free} and \$D{reservation}{tarif} eq 'free'){
     return 0;
 }
 my \$price = \$D{reservation}{duration} * \$D{room}{price_norm};
 if (\$D{reservation}{tarif} eq 'noprof'){
     \$price = \$D{reservation}{duration} * \$D{room}{price_noprof};
 }
 \$price = 100 if \$price < 100;
 return \$price;

 *** ROOM: salon ***
 name = Salon
 m_2 = 65
 description = Grosser Raum mit Garten Zugang

 +DATA_PL
 return { 
    price_norm => 15,
    price_noprof => 25 
 }

 *** ROOM: sitz ***
 name = Sitzungszimmer
 m_2 = 12
 description = Kleiner Besprechungsraum
 
 +DATA_PL
 return { 
    price_norm => 20,
    price_noprof => 35 
 }
 
${E}head1 DESCRIPTION

Qroombo configuration is based on L<Config::Grammar>. The following options
are available.

HEADER

}

=head2 $x->B<_make_parser>()

Create a config parser for DbToRia.

=cut

sub _make_parser {
    my $self = shift;
    my $E = '=';

    my $compileD = sub { 
        my $code = $_[0] || '';
        # check and modify content in place
        my $perl = 'sub { my %D = (%{$_[0]}); '.$code.'}';
        my $sub = eval $perl; ## no critic (ProhibitStringyEval)
        if ($@){
            return "Failed to compile $code: $@ ";
        }        
        eval { $sub->({}) };
        if ($@){
            return "Failed to compile $code: $@ ";
        }        
        $_[0] = $sub;
        return;
    };
    my $EXTRA_FIELDS_SUB = sub { 
        my $code = $_[0] || '[]';
        # check and modify content in place
        my $perl = 'sub { my %D = (%{$_[0]}); '.$code.'}';
        my $sub = eval $perl; ## no critic (ProhibitStringyEval)
        if ($@){
            return "Failed to compile $code: $@ ";
        }
        my $array = eval { $sub->({}) };
        if ($@){
            return "Failed to run $code: $@ ";
        }
        if (ref $array !~~ 'ARRAY'){
            return "Code does not return an array pointer: $code ";
        }
        $_[0] = $sub;
        return;
    };
    my $EXTRA_FIELDS_DOC = <<DOC_END;

A perl expression to return an array pointer with extra field definitions
for this section. The perl will get executed at runtime. It has
access to the C<%D> hash containing three keys with information about the
user, the billing address and the admin mode.

 %D = (
    user => {
        user_id => xxx,
        user_first => xxx,
        ...
    },
    addr => {
        addr_id => xxx,
        addr_org => xxx,
        addr_contact => xxx,
    },
    adminMode => 1|0
 )

An extra field entries support the following keys:

=over

=item key

the name of the field

=item insertBefore

set the position of the entry when shown in a form, relative to the static entries

=item widget  (default text)

select the autoform widget to display this item

=item label

the text to put in front of the widget name

=item set

set standard widget properties

=item cfg

provide extra configuration for autoform

=item access

a hash with entries for admin and user, providing read, write and none access

 access = { user => 'read', admin => 'write' }

=back

DOC_END
    my $grammar = {
        _sections => [ qw{ GENERAL MAIL RESERVATION USER ADDRESS ROOM /ROOM:\s*\S+/ }],
        _mandatory => [qw{ GENERAL MAIL RESERVATION USER ADDRESS ROOM }],
        GENERAL => {
            _doc => 'Global configuration settings for Qroomo',
            _vars => [ qw(database_dir secret log_file log_level title admin) ],
            _mandatory => [ qw(database_dir secret log_file admin) ],
            database_dir => { _doc => 'where to keep the qroombo database',
                _sub => sub {
                    if ( not -d $_[0] ){
                        system "/bin/mkdir","-p",$_[0];
                    }
                    -d $_[0] ? undef : "Database directory $_[0] does not exist (and could not be created)";
                }
            },
            secret => { _doc => 'secret for signing mojo cookies' },
            log_file => { _doc => 'write a log file to this location (unless in development mode)'},
            log_level => { _doc => 'what to write to the logfile'},
            title => { _doc => 'tite to show in the top right corner of the app' },
            admin => { 
                _doc => 'comma separated list of admin email addresses',
                _sub => sub {
                    $_[0] = { map { $_ => 1 } split /\s+/, $_[0] };
                    return undef;
                },
                _example => 'user@a.ch, user2@b.com'
            }
        },
        MAIL => {
            _doc => 'Mail configuration',
            _vars => [ qw(smtp_server sender) ],
            _sections => [ qw(KEYMAIL) ],
            _mandatory => [ qw(sender KEYMAIL) ],
            sender => { _doc => 'sender address for Qroom eMails' },
            smtp_server => { _doc => 'smtp server adddress', _default=>'localhost' },
            KEYMAIL => {
                _doc => <<DOC_END,
The mail to send to people login in. Example

From: Qroombo <sender\@address>
To: {TO}
Subject: your qroombo key

You Qroombo key is {KEY}
DOC_END
                _text => {}
            }
        },
        RESERVATION => {
            _doc => 'Frontend tuneing parameters',
            _vars => [ qw(first_hour last_hour) ],
            _mandatory => [ qw(first_hour last_hour) ],
            _sections => [ qw(EXTRA_FIELDS_PL) ],
            first_hour => { _doc => 'from which time in the morning should RESERVATION be pssible' },
            last_hour  => { _doc => 'which is the last hour to reserve (23 means until midnight)' },
            EXTRA_FIELDS_PL => {
                _doc => $EXTRA_FIELDS_DOC,
                _text => {
                    _sub => $EXTRA_FIELDS_SUB
                }
            },
        },
        USER => {
            _sections => [ qw(EXTRA_FIELDS_PL) ],
            EXTRA_FIELDS_PL => {
                _doc => $EXTRA_FIELDS_DOC,
                _text => {
                    _sub => $EXTRA_FIELDS_SUB
                }
            },
        },
        ADDRESS => {
            _sections => [ qw(EXTRA_FIELDS_PL) ],
            EXTRA_FIELDS_PL => {
                _doc => $EXTRA_FIELDS_DOC,
                _text => {
                    _sub => $EXTRA_FIELDS_SUB
                }
            },
        },

        ROOM => {
            _sections => [ qw(PRICE_PL) ],
            _mandatory => [ qw(PRICE_PL) ],
            PRICE_PL => {
                _doc => 'Perl function to calculat the room price. The %D hash contains information about address, reservation.',
                _text => {
                    _sub => $compileD
                }
            },
        },
        '/ROOM:\s*\S+/' => {
            _order => 1,
            _doc => 'Information on the rooms available for rent through this system',
            _vars => [ qw(name m_2 description) ],
            _mandatory => [ qw(name m_2 description) ],
            _sections => [qw(DATA_PL) ],
            name => {
                _doc => 'Name of the room'
            },
            m_2 => {
                _doc => 'Size of the room im m^2'
            },
            description => {
                _doc => 'A few words on the room',
            },
            DATA_PL => {
                _doc => 'A Perl expression to return data available to PRICE_PL via $D{room}',
                _text => {
                    _sub => $compileD,
                }
            },
        },
    };
    my $parser =  Config::Grammar->new ($grammar);
    return $parser;
}

1;
__END__

=head1 SEE ALSO

L<Config::Grammar>

=head1 COPYRIGHT

Copyright (c) 2011 by OETIKER+PARTNER AG. All rights reserved.

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

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2012-08-01 to 1.0 first version

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

