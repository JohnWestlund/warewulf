package Warewulf::Module::REST::Vnfs;


use Dancer;
use Dancer::Plugin::REST;
use Warewulf::Module::EasyFuncs::Vnfs qw(get_all_vnfs get_single_vnfs);

#set serializer => 'mutable';
set serializer => 'JSON';
prefix '/vnfs';

# REST routes
get '/' => \&list_all_images;
get '/:vnfsid' => \&list_single_image;
post '/' => \&not_implemented;
del '/:vnfsid' => \&not_implemented;

sub not_implemented {
    status(501);
    return { 'error' => 'This action has not yet been implemented' };
}

sub list_all_images {
    my %vnfs;
    my $out = params->{output} || undef;
    eval { 
        %vnfs = get_all_vnfs($out);
        status(200);
        return { 'vnfs' => \%vnfs };
        1;
    } or do {
        status(500);
        return { 'error' => "$@" };
    };
}

sub list_single_image {
    my $vnfsid = params->{vnfsid} || undef;
    my %vnfs;
    eval {
        %vnfs = get_single_vnfs($vnfsid);
        status(200);
        return { 'vnfs' => \%vnfs };
        1;
    } or do {
        status(500);
        return { 'error' => "$@" };
    };
}

