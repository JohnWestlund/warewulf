package Warewulf::Module::EasyFuncs::Vnfs;

use Warewulf::DataStore;
use Warewulf::Vnfs;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(get_all_vnfs get_single_vnfs);

sub get_all_vnfs {
    my $db = Warewulf::DataStore->new();
    my $vnfsSet = $db->get_objects('vnfs');
    return vnfs_hash(undef, $vnfsSet);
}

sub get_single_vnfs {
    my $vnfsid = shift || undef
    my $lookup;
    if (!$vnfsid) {
        return undef;
    }
    if ($vnfsid =~ /^([0-9]+)/) {
        $lookup = "_id";
    } elsif ($vnfsid =~ /^([a-zA-Z0-9\-_\.]+)/) {
        $lookup = "name";
    }

    my $db = Warewulf::DataStore->new();
    my $vnfsSet = $db->get_objects('vnfs',$lookup,$vnfsid);
    return vnfs_hash($vnfsid, $vnfsSet);
}

sub vnfs_hash($@) {
    my $vnfsid = shift;
    my $vnfsSet = shift;
    my %vnfs;
    foreach my $v ($vnfsSet->get_list()) {
        my $id = $vnfsid || $v->get('name');
        $vnfs{$id}{'name'} = $v->get('name');
        $vnfs{$id}{'id'} = $v->get('_id');
        $vnfs{$id}{'size'} = $v->get('size');
    }
    return %vnfs;
}

sub clean_size {
    my $size = shift || undef;

    if (! $size) {
        return undef;
    }

    my $len = sprintf "%d", length($size)/4;
    my $ext="KB";
    if ($len <= 1) {
        $ext = "KB";
    } elsif ($len <= 2) {
        $ext = "MB";
    } elsif ($len <= 3) {
        $ext = "GB";
    }
    my $s = $size;
    for ( my $i=0; $i < $len; $i++ ) {
        $s = $s/1024;
    }
    my $ret = sprintf "%5.2f %s", $s, $ext;

    return $ret;
}

1;

