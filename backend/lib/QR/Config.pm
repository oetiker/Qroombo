package QR::Config;
use strict;  
use warnings;

=head1 NAME

QR::Config - The Qroombo File

=head1 SYNOPSIS

 use QR::Config;

 my $parser = QR::Config->new(file=>'/etc/extopus/system.cfg');

 my $cfg = $parser->parse_config();
 my $pod = $parser->make_pod();

=head1 DESCRIPTION

Configuration reader for Extopus

=cut

use Carp;
use Config::Grammar;
use Mojo::Base -base;

use POSIX qw(strftime);

=head2 ATTRIBUTES

=head3 file

the path to the config file

=cut

has 'file';

=head3 cfg

pointing to the map with the data from the config file.

=cut

has 'config';

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
    for my $section (keys %$cfg){
        # list compiled code sections up
        for my $key (keys %{$cfg->{$section}}){
            next unless $key =~ /_PL$/ and $cfg->{$section}{$key}{_text};
            $cfg->{$section}{$key} = $cfg->{$section}{$key}{_text};
        }
        # mode per room configs into the ROOM key
        if ($section =~ /^ROOM:\s*(\S+)/){
            $cfg->{ROOM}{$1} = $cfg->{$section};
            delete $cfg->{$section};
        }
    }
    return $self->cfg($cfg);
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
 admin = tobi@oetiker.ch,doris@oetiker.ch
 mojo_secret = very_secret_cookie_secret
 log_file = /tmp/qroombo.log
 log_level = debug
 database_dir = /tmp/qroombo
 title = Flörli Olten
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

 +SELECTBOX_CFG_PL
 my \$ret = [
    { key => 'noprof', title => 'Non Profit Tarif' },
    { key => 'normal', title => 'Normaltarif' },     
 ];
 if (\$D{address}{allow_free}){
      unshift @$ret, { key => 'free', title => 'Gratis Nutzung' };   
 }

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
        my $code = $_[0];
        # check and modify content in place
        my $perl = 'sub { my %R = (%{$_[0]}); '.$code.'}';
        my $sub = eval $perl; ## no critic (ProhibitStringyEval)
        if ($@){
            return "Failed to compile $code: $@ ";
        }
        $_[0] = $sub;
        return;
    };

    my $grammar = {
        _sections => [ qw{GENERAL RESERVATION USER ADDRESS ROOM /ROOM:\s*\S+/ }],
        _mandatory => [qw(GENERAL RESERVATION USER ADDRESS ROOM /ROOM:\s*\S+/ )],
        GENERAL => {
            _doc => 'Global configuration settings for Qroomo',
            _vars => [ qw(database_dir mojo_secret log_file log_level title) ],
            _mandatory => [ qw(databse_dir mojo_secret log_file) ],
            database_dir => { _doc => 'where to keep the qroombo database',
                _sub => sub {
                    if ( not -d $_[0] ){
                        system "/bin/mkdir","-p",$_[0];
                    }
                    -d $_[0] ? undef : "Database directory $_[0] does not exist (and could not be created)";
                }
            },
            mojo_secret => { _doc => 'secret for signing mojo cookies' },
            log_file => { _doc => 'write a log file to this location (unless in development mode)'},
            log_level => { _doc => 'what to write to the logfile'},
            title => { _doc => 'tite to show in the top right corner of the app' },
        },
        RESERVATION => {
            _doc => 'Frontend tuneing parameters',
            _vars => [ qw(first_hour last_hour) ],
            _mandatory => [ qw(first_hour last_hour) ],
            _sections => [ qw(EXTRA_FIELDS_PL SELECTBOX_CFG_PL) ]
            first_hour => { _doc => 'from which time in the morning should RESERVATION be pssible' },
            last_hour  => { _doc => 'which is the last hour to reserve (23 means until midnight)' },
            EXTRA_FIELDS_PL => {
                _doc => 'Extra information to store with RESERVATION. Perl expression must return array pointer in AutoForm syntax.',
                _text => {
                    _sub => $compileD
                }
            },
            SELECTBOX_CFG_PL => {
                _doc => 'Extra information to store with RESERVATION. Perl expression must return array pointer in AutoForm syntax.',
                _text => {
                    _sub => $compileD
                }
            },
        },
        USER => {
            _sections => [ qw(EXTRA_FIELDS_PL) ]
            EXTRA_FIELDS_PL => {
                _doc => 'Extra information to be store together with information on people using the system. Perl expression must return array pointer in AutoForm syntax.',
                _text => {
                    _sub => $compileD
                }
            },
        },
        ADDRESS => {
            _sections => [ qw(EXTRA_FIELDS_PL) ]
            EXTRA_FIELDS_PL => {
                _doc => 'Extra information to stored with invoice addresses. Perl expression must return array pointer in AutoForm syntax.',
                _text => {
                    _sub => $compileD
                }
            },
        },

        ROOM => {
            _sections => [ qw(PRICE_PL) ]
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
                _sub => $compileD,
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

