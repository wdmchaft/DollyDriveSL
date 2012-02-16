#!/bin/ksh

eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)

PERL5LIB=$HOME/preview:$PERL5LIB
export PERL5LIB

# using my hacked HTTP::Server::PSGI in preview/ for SSL support
# this is non-forking, but this isn't a production solution...
plackup -s HTTP::Server::PSGI -p 3000 $HOME/preview/server.pl
