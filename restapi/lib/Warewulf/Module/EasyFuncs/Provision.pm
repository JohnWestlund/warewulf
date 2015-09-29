package Warewulf::Module::EasyFuncs::Provision;

use Warewulf::DataStore;
use Warewulf::Node;
use Warewulf::Vnfs;
use Warewulf::File;
use Warewulf::Provision;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(get_all_provision get_single_provision);

sub get_all_provision {
    my $db = Warewulf::DataStore->new();
    my $pSet = $db->get_objects('node');
    return provision_hash($pSet);
}

sub get_single_provision {
    my $lookup = shift;
    my $ref = shift;

    if (ref($ref) eq 'ARRAY') {
        @ident = @{$ref};
    } else {
        push(@ident,$ref);
    }

    my $db = Warewulf::DataStore->new();
    my $pSet = $db->get_objects("node", "$lookup", @ident);

    return provision_hash($pSet);
}

sub provision_hash {
    my $pSet = shift;
    my %provision;
    foreach my $n ($pSet->get_list()) {
        my $id = $n->get('name');
        $provision{$id}{'name'} = $n->get('name');
        $provision{$id}{'_id'} = $n->get('_id');
        $provision{$id}{'bootlocal'} = ($n->bootlocal() ? "True" : "False");
        $provision{$id}{'preshell'} = ($n->preshell() ? "True" : "False");
        $provision{$id}{'postshell'} = ($n->postshell() ? "True" : "False");
        $provision{$id}{'fileids'} = join(",", $n->fileids());
        $provision{$id}{'kargs'} = join(" ", $n->kargs()) || "UNDEF";
        $provision{$id}{'vnfs'}{'_id'} = $n->vnfsid() || "UNDEF";
        $provision{$id}{'vnfs'}{'name'} = $n->vnfs();
        $provision{$id}{'bootstrap'}{'_id'} = $n->bootstrapid() || "UNDEF";
        $provision{$id}{'bootstrap'}{'name'} = $n->bootstrap();
        $provision{$id}{'disk'}{'filesystems'} = $n->get('filesystems') || "UNDEF";
        $provision{$id}{'disk'}{'diskformat'} = $n->get('diskformat') || "UNDEF";
        $provision{$id}{'disk'}{'diskpartition'} = $n->get('diskpartition') || "UNDEF";
    }
    return %provision;
}

1;

