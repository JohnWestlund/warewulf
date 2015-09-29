package Warewulf::Module::EasyFuncs::Node;

use Warewulf::DataStore;
use Warewulf::Node;
use Warewulf::DSO::Node;
use Warewulf::Provision::Pxelinux;
use Warewulf::Provision::HostsFile;
use Warewulf::Provision::DhcpFactory;
use Warewulf::ParallelCmd;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(get_all_nodes nodes_by_cluster get_nodes del_node_properties set_node_properties reboot_nodes poweron_nodes poweroff_nodes power_action powerstatus_nodes);

# get_all_nodes
#   Return full hash of all nodes provisioned by Warewulf.
#   Return nodeid, node name, ip/netmask of eth0,
#   cluster, hwaddr, vnfsid, bootstrapid, fileids.
sub get_all_nodes {
    my $lookup = shift || undef;
    my $db = Warewulf::DataStore->new();
    my $nodeSet = $db->get_objects("node");
    my %nodes = nodes_hash($nodeSet, $lookup);
    return %nodes;
}

# get_nodes
#   Using a given lookup, return all nodes with that parameter.
sub get_nodes {
    my $lookup = shift;
    my $ref = shift;
    my @ident;
    if (ref($ref) eq 'ARRAY') {
        @ident = @{$ref};
        #print "array = $ident[0]\n";
    } else {
        push(@ident,$ref);
    }
    my $db = Warewulf::DataStore->new();
    my $nodeSet = $db->get_objects('node',"$lookup",@ident);
    #print "Count = " . $nodeSet->count() . "\n";
    #print "Lookup = " . $lookup . "\n";
    return nodes_hash($nodeSet,$lookup);
}

# nodes_by_cluster
#   Return node hash of nodes in a given cluster.
sub nodes_by_cluster {
    my $cluster = shift;
    if ($cluster eq "UNDEF") {
        $cluster = undef;
    }
    my $db = Warewulf::DataStore->new();
    my $nodeSet = $db->get_objects('node','cluster',($cluster));
    return nodes_hash($nodeSet);
}

# del_node_properties
#   Delete a set of keys from a given list of nodes.
sub del_node_properties {
    my $noderef = shift;
    my @idlist = @{$noderef};
    my $keyref = shift;
    my @keys = @{$keyref};

    eval {
    my $nodeSet = $db->get_objects('node','_id',@idlist);
    foreach my $n ($nodeSet->get_list()) {
        foreach my $k (@keys) {
            $n->del($k);
        }
    }
    $db->persist($nodeSet);
    };
    return $@;
}

# set_node_properties
#   Sets node properties according to a passed hash.
#   (\%nodehash)
sub set_node_properties {
    my $p = shift;
    my %props = %{$p};

    my $db = Warewulf::DataStore->new();
    my @idlist;

    foreach my $id (keys %props) {
        push(@idlist,$id);
        my $node = ( ($db->get_objects('node','_id',($id)))->get_list() )[0];
        my @netdevs = $node->get('netdevs');
        foreach my $p (keys %{ $props{$id} } ) {
            print "Nodeid $id Prop $p = $props{$id}{$p} \n";
            if (lc($p) eq 'netdevs') {
                foreach my $nd (@netdevs) {
                    if ($props{$id}{$p}{$nd->get('name')}) {
                        foreach my $ndparam ( keys %{ $props{$id}{$p}{$nd->get('name')} } ) {
                            $nd->set($ndparam, $props{$id}{$p}{$nd->get('name')}{$ndparam});
                        }
                    }
                }
            } elsif (ref($props{$id}{$p}) =~ /^ARRAY/) {
                my @arr = @{ $props{$id}{$p} };
                $node->set($p,@arr);
            } else {
                $node->set($p,$props{$id}{$p});
            }
        }
        $db->persist($node);
    }
    
    my $pxe = Warewulf::Provision::Pxelinux->new();
    my $dhcp = Warewulf::Provision::DhcpFactory->new();
    my $hostsfile = Warewulf::Provision::HostsFile->new();
    my $nodeSet = $db->get_objects('node','_id',@idlist);
    
    #$dhcp->persist();
    $hostsfile->update_datastore();
    #$pxe->update($nodeSet);

    return nodes_hash($nodeSet);
}

# power_status_nodes
sub powerstatus_nodes {
    my $lookup = shift;
    my $ref = shift;
    my @ident;
    if (ref($ref) eq 'ARRAY') {
        @ident = @{$ref};
    } else {
        push(@ident,$ref);
    }

    my %results;
    my $db = Warewulf::DataStore->new();
    my $nodeSet = $db->get_objects('node',$lookup,@ident);
    foreach my $o ($nodeSet->get_list()) {
        if (my $ipaddr = $o->get("ipmi_ipaddr") and my $username = $o->get("ipmi_username") and my $password = $o->get("ipmi_password")) {
            $results{$o->get("_id")} = `ipmitool -I lan -U $username -P $password -H $ipaddr power status`;
        } else {
            $results{$o->get("_id")} = "fail";
        }
    }

    return %results;
}


# poweroff_nodes
sub poweroff_nodes {
    my $lookup = shift;
    my $ref = shift;
    my @ident;
    if (ref($ref) eq 'ARRAY') {
        @ident = @{$ref};
    } else {
        push(@ident,$ref);
    }

    return power_action($lookup,"power off",\@ident);
}

# poweron_nodes
sub poweron_nodes {
    my $lookup = shift;
    my $ref = shift;
    my @ident;
    if (ref($ref) eq 'ARRAY') {
        @ident = @{$ref};
    } else {
        push(@ident,$ref);
    }

    return power_action($lookup,"power on",\@ident);
}

# reboot_nodes
sub reboot_nodes {
    my $lookup = shift;
    my $ref = shift;
    my @ident;
    if (ref($ref) eq 'ARRAY') {
        @ident = @{$ref};
    } else {
        push(@ident,$ref);
    }

    return power_action($lookup,"power cycle",\@ident);
}

# power_action
#   ($lookup, $action, @ident)
sub power_action {
    my $lookup = shift;
    my $action = shift;
    my $ref = shift;
    my @ident;
    if (ref($ref) eq 'ARRAY') {
        @ident = @{$ref};
    } else {
        push(@ident,$ref);
    }

    my %results;
    my $db = Warewulf::DataStore->new();
    my $nodeSet = $db->get_objects('node',$lookup,@ident);
    my $cmd = Warewulf::ParallelCmd->new();
    $cmd->fanout(4);
    foreach my $o ($nodeSet->get_list()) {
        if (my $ipaddr = $o->get("ipmi_ipaddr") and my $username = $o->get("ipmi_username") and my $password = $o->get("ipmi_password")) {
            $cmd->queue("ipmitool -I lan -U $username -P $password -H $ipaddr chassis $action");
            $results{$o->get('_id')}{"status"} = "IPMI $action sent";
        } else {
            $results{$o->get('_id')}{'status'} = "error";
            $results{$o->get('_id')}{'error'} = "Node IPMI settings not complete";
        }
    }
    $cmd->run();
    return %results;
}


sub nodes_hash {
    my $nodeSet = shift;
    my $lookup = shift || undef;
    my %result;

    if (!defined $lookup) {
        $lookup = "name";
    }
    # print "nodes_hash() -- Lookup = " . $lookup . "\n";
    foreach my $node ($nodeSet->get_list()) {
        my $name;
        # Check for a lookup value. Fall back onto nodename.
        if ($lookup eq "_id" or $lookup eq "id") {
            $name = $node->id();
        } elsif ($lookup eq "_hwaddr" or $lookup eq "hwaddr") {
            # $name = $node->hwaddr();
            $name = $node->get("_hwaddr");
        } else {
            $name = $node->nodename();
        } 
        $result{$name}{'_id'} = $node->id();
        my %hash = $node->get_hash();
        foreach my $k (keys %hash) {
            if (lc($k) eq 'netdevs') {
                foreach my $nd ($node->netdevs()->get_list()) {
                    my $ndname = $nd->get('name');
                    my %ndh = $nd->get_hash(); # keys() requires a hash
                    # foreach my $l ($nd->lookups()) {
                    foreach my $l (keys(%ndh)) {
                        $result{$name}{lc($k)}{lc($ndname)}{lc($l)} = $nd->get($l);
                    }
                }
            } else {
                $result{$name}{lc($k)} = $hash{$k}
            }
        }

    }
    return %result;
}


