package Warewulf::Module::REST::Provision;


use Dancer;
use Dancer::Plugin::REST;
use Warewulf::Module::EasyFuncs::Provision qw(get_all_provision get_single_provision);

#set serializer => 'mutable';
set serializer => 'JSON';
prefix '/provision';

# REST routes
get '/' => \&list_provision;
get '/:nodeid' => \&list_single_provision;
post '/' => \&not_implemented;
del '/:nodeid' => \&not_implemented;

sub not_implemented {
    status(501);
    return { 'error' => 'This action has not yet been implemented' };
}

sub list_provision {
    my %provision;
    eval { 
        %provision = get_all_provision();
        status(200);
        return { 'provision' => \%provision };
        1;
    } or do {
        status(500);
        return { 'error' => "$@" };
    };
}

sub list_single_provision {
    my %provision;
    my $nodeid;
    my @nodelist;
    eval {
        $nodeid = params->{nodeid};
        @nodelist = ("$nodeid");
        if ( $nodeid =~ m/((?:[0-9a-f]{2}:){5,7}[0-9a-f]{2})$/ ) {  # Same match from Warewulf::Module::Cli::Node
            %provision = get_single_provision('_hwaddr', \@nodelist);
        } elsif ( $nodeid =~ m/^([0-9]+)/ ) {
            %provision = get_single_provision('_id', \@nodelist);
        } elsif ( $nodeid =~ m/^(\w+)/ ) {
            %provision = get_single_provision('name',\@nodelist);
        } else {
            status(500);
            return { "error" => "Unrecognized \$nodeid value: $nodeid" };
        }

        if (%provision) {
            status(200);
            return { 'provision' => \%provision };
        } else {
            status(404);
            return { "error" => "nodeid = $nodeid does not exist. No node returned." };
        }
        1;
    } or do {
        status(500);
        return { 'error' => "$@" };
    };
}

