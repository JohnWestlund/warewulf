package Warewulf::Module::REST::Node;

use Dancer;
use Warewulf::Module::EasyFuncs::Node qw(get_all_nodes nodes_by_cluster get_nodes del_node_properties set_node_properties reboot_nodes poweron_nodes poweroff_nodes power_action powerstatus_nodes);

#set serializer => 'mutable';
set serializer => 'JSON';
prefix '/node';

# REST routes
get '/' => \&all_node_data;
get '/list' => \&list_nodes;
get '/:hwid' => \&get_node_data;
get '/:hwid/pstatus' => \&get_node_powerstatus;
get '/lookup/:hwid' => \&get_by_lookup;
post '/:hwid' => \&provision_node;
post '/:hwid/action' => \&perform_node_action;
del '/:hwid' => \&deprovision_node;
put '/:hwid' => \&update_node_data;

# functions to serve routes

sub all_node_data {
    my %nodes;
    my $lookup = params->{lookup} || undef;
    eval { 
        %nodes = get_all_nodes($lookup);
        status(200);
        return { 'nodes' => \%nodes };
        1;
    } or do {
        status(500);
        return { 'error' => "$@" };
    };
}

sub list_nodes {
    my %nodes;
    my %result;
    eval { 
        %nodes = get_all_nodes();
        foreach my $id (keys %nodes) {
            $result{$id}{'_id'} = $nodes{$id}{'_id'};
            $result{$id}{'name'} = $nodes{$id}{'name'};
            $result{$id}{'groups'} = $nodes{$id}{'groups'};
            $result{$id}{'_hwaddr'} = $nodes{$id}{'_hwaddr'};
        }
        status(200);
        return { 'nodes' => \%result };
        1;
    } or do {
        status(500);
        return { 'error' => "$@" };
    };
}

sub get_node_data {
    my %node;
    my $hwid;
    my @nodelist;
    eval {
        $hwid = params->{hwid};
        @nodelist = ("$hwid");   # get_nodes requires an arrayref
        if ( $hwid =~ m/((?:[0-9a-fA-F]{2}:){5,7}[0-9a-fA-F]{2})$/ ) {  # Same match from Warewulf::Module::Cli::Node
            #print "hwaddr: Match was: $1\n";
            #print "\@nodelist: @nodelist\n";
            %node = get_nodes('_hwaddr', \@nodelist);
        } elsif ( $hwid =~ m/^([0-9]+)/ ) {
            #print "id: Match was $1\n";
            #print "\@nodelist: @nodelist\n";
            %node = get_nodes('_id', \@nodelist);
        } elsif ( $hwid =~ m/^(\w+)/ ) {
            #print "name: Match was: $1\n";
            #print "\@nodelist: @nodelist\n";
            %node = get_nodes('name', \@nodelist);
        } else {
            status(500);
            return { "error" => "Unrecognized \$hwid value: $hwid" };
        }

        if(%node) {
            #use Data::Dumper;
            #print Dumper(%node) . "\n";
            #print " ---------- \n";
            #print " ---- Keys ---- \n";
            #foreach my $k (keys(%node)) {
            #    print "$k\n";
            #}
            if($node{$hwid}{'_id'}) {
                status(200);
                return {"node" => \%node};
            } else {
                status(404);
                return { "error" => "hwid = $hwid does not exist. No id returned." };
            }
        } else {
            status(404);
            return { "error" => "hwid = $hwid does not exist. No nodes returned." };
        }
        1;
    } or do {
        status(500);
        return { "error" => "$@" };
    };
}

sub get_by_lookup {
    my %node;
    my $hwid;
    my $lval;
    my @nodelist;
    eval {
        $hwid = params->{hwid};
        $lval = params->{lval} || undef;
        @nodelist = ("$lval");
        #print "\$hwid = $hwid, \$lval = $lval\n";
        %node = get_nodes("$hwid", \@nodelist);

        if(%node) {
            status(200);
            return { "node" => \%node };
        } else {
            status(404);
            return { "error" => "Failure getting nodes for a lookup of: $hwid $lval" };
        }
        1;
    } or do {
        status(500);
        return { "error" => "$@" };
    };
}

sub update_node_data {
    my $json = params->{json};
    my $href = from_json($json);
    my %node_data = %{$href};
    my %nodes_hash = set_node_properties(\%node_data);
    return %nodes_hash;
}

sub provision_node {

    eval {
    my $json = params->{json};
    my @hwid = (params->{hwid});
    my $href = from_json($json);
    my %node_data = %{$href};
    my %nodes_hash = set_node_properties(\%node_data);
    my %poresult = poweron_nodes('_id',\@hwid);
    my %rbresult = reboot_nodes('_id',\@hwid);
    status(200);
    return { "nodes" => \%nodes_hash, "poweron" => \%poresult, "reboot" => \%rbresult };
    1;
    } or do {
        status(500);
        return { "error" => "$@" };
    };
}

sub get_node_powerstatus {
    eval {
        my $hwid = params->{hwid};
        my @nodelist = ("$hwid");
        my $lookup = '_id';
        my %result = powerstatus_nodes($lookup,\@nodelist);
        status(200);
        return { 'result' => \%result };
    } or do {
        status(500);
        return { 'error' => $@ };
    };
}

sub perform_node_action {
    eval {
    my $hwid = params->{hwid};
    my $action = params->{action};
    my @nodelist = ("$hwid");

    # Check if node exists
    my %node = get_nodes('_id',\@nodelist);
    if (! $node{$hwid}{'_id'}) {
        status(404);
        return { "error" => "Node $hwid does not exist" };
    }

    my %result;
    my $lookup = '_id';
    if (lc($action) eq 'reboot') {
        %result = reboot_nodes($lookup,\@nodelist); 
    } elsif (lc($action) eq 'poweroff') {
        %result = poweroff_nodes($lookup,\@nodelist);
    } elsif (lc($action) eq 'poweron') {
        %result = poweron_nodes($lookup,\@nodelist);
    }
    status(200);
    return { 'result' => \%result };
    1;
    } or do {
        status(500);
        return { "error" => "$@" };
    }
}

# Utility functions

# Define a "free" node as one with "owner_id" unset
sub list_free_nodes {
    my %nodes = get_all_nodes();
    my $param = 'owner_id';
    my @hwids;
    foreach my $id (keys %nodes) {
        if ($nodes{$id}{$param} == undef) {
            push(@hwids,$id);
        }
    }
    return @hwids;
}


sub allocate_nodes {
    my $count = shift;
    my $owner_id = shift;
    my %nodehash;

    my @free = list_free_nodes();
    my @new;
    for (my $i=0;$i<$count;$i++) {
        my $id = pop(@free);
        $nodehash{$id}{'owner_id'} = $owner_id;
        push(@new,$id);
    }
    my %result = set_node_properties(\%nodehash);

    return @new;
}

sub deallocate_nodes {
    my $idref = shift;
    my @ids = @{$idref};
    my @keys = ("owner_id");

    eval { my $error = del_node_properties(\@ids,\@keys); };
    if ($@) {
        return $@;
    } else {
        return true;
    }
}
