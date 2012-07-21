#!/bin/bash

. `dirname $0`/sdbs.inc

for module in \
    Mojolicious \
    MojoX::Dispatcher::Qooxdoo::Jsonrpc \
    Mojo::Server::FastCGI \
    Config::Grammar \
    DBI \
    DBD::SQLite \
; do
    perlmodule $module
done

#    Devel::NYTProf 
        
