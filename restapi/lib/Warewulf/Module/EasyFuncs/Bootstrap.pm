package Warewulf::Module::EasyFuncs::Bootstrap;

use Warewulf::DataStore;
use Warewulf::Object;
use Warewulf::Bootstrap;
use Warewulf::DSO::Bootstrap;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(get_all_bootstraps get_single_bootstrap);

sub get_all_bootstraps {
    my $db = Warewulf::DataStore->new();
    my $bootstrapSet = $db->get_objects('bootstrap');
    return bootstrap_hash($bootstrapSet);
}

sub get_single_bootstrap {
    my $kname = shift || undef;
    my $lookup = shift || undef;

    if (!defined $kname) {
        return undef;
    }
    if ($lookup =~ /^(0-9)+/) {
        $lookup = "_id";
    }
    if (!defined $lookup) {
        $lookup = "name";
    }

    my $db = Warewulf::DataStore->new();
    my $bs = $db->get_objects('bootstrap', "$lookup", "$kname");
    return bootstrap_hash($bs);
}
 
sub bootstrap_hash {
    my $bsSet = shift;
    my %bs;
    foreach my $b ($bsSet->get_list()) {
        my $id = $b->get('name');
        $bs{$id}{'name'} = $b->get('name');
        $bs{$id}{'id'} = $b->get('_id');
        $bs{$id}{'size'} = $b->get('size');
    }
    return %bs;
}
