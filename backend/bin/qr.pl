#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../thirdparty/lib/perl5";
use lib "$FindBin::Bin/../lib";
# use lib qw() # PERL5LIB
use Mojolicious::Commands;
use QR;

our $VERSION = "0";

local $ENV{MOJO_APP} = 'QR';

# Start commands
Mojolicious::Commands->start_app('QR');
