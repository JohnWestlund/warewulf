package Warewulf::Module::REST::Bootstrap;


use Dancer;
use Dancer::Plugin::REST;
use Warewulf::Module::EasyFuncs::Bootstrap qw(get_all_bootstraps get_single_bootstrap);

#set serializer => 'mutable';
set serializer => 'JSON';
prefix '/bootstrap';

# REST routes
get '/' => \&list_bootstraps;
get '/:bsid' => \&get_bootstrap;
post '/' => \&not_implemented;
del '/:bsid' => \&not_implemented;

sub not_implemented {
    status(501);
    return { 'error' => 'This action has not yet been implemented' };
}

sub list_bootstraps {
    my %bs;
    eval { 
        %bs = get_all_bootstraps();
        status(200);
        return { 'kernels' => \%bs };
        1;
    } or do {
        status(500);
        return { 'error' => "$@" };
    };
}

sub get_bootstrap {
    my %bs;
    my $bsname = params->{bsid};
    my $lookup = params->{lookup} || undef;
    if (!$lookup) {
        if ($bsname =~ /^[0-9]+/) {
            $lookup = "_id";
        }
    }
    eval {
        %bs = get_single_bootstrap($bsname, $lookup);
        if(%bs) {
            status(200);
            return { 'kernels' => \%bs };
        } else {
            status(500);
            return { 'error' => "Bootstrap $bsname not found." };
        }
        1;
    } or do {
        status(500);
        return { 'error' => "$@" };
    }
}

