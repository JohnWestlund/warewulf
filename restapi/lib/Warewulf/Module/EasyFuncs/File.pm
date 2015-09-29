package Warewulf::Module::EasyFuncs::File;

use Warewulf::Object;
use Warewulf::DataStore;
use Warewulf::DSO::File;
use Warewulf::Util;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(get_all_files get_files get_file_contents set_file_properties create_new_file set_file_contents del_file);

sub get_all_files {
    my $db = Warewulf::DataStore->new();
    #my $fileSet = $db->get_objects('file','_id',());
    my $fileSet = $db->get_objects('file');
    return files_hash($fileSet);
}


sub get_files {
    my $lookup = shift;
    my $ref = shift;
    my @ident;
    if (ref($ref) eq 'ARRAY') {
        @ident = @{$ref};
    } else {
        push(@ident,$ref);
    }
    my $db = Warewulf::DataStore->new();
    my $fileSet = $db->get_objects('file',$lookup,@ident);
    return files_hash($fileSet);
}


sub get_file_contents {
    my $id = shift;
    my $fid = undef;
    my $db = Warewulf::DataStore->new();
    if ( $id =~ m/^([0-9]+)$/ ) {
        $fid = $id;
    } elsif ( $id =~ m/^([\w-.]+)$/ ) {
        my $objs = $db->get_objects('file', "name", $id);
        foreach my $f ($objs->get_list()) {
            $fid = $f->id();
        }
    } else {
        return undef;
    }
    if (! $fid) {
        return undef;
    }
    my $binstore = $db->binstore($fid);
    my $contents = "";
    Dancer::debug( "In EasyFuncs::File->get_file_contents()" );
    while (my $buffer = $binstore->get_chunk()) {
        #Dancer::debug( "In While Loop" );
        $contents = $contents . $buffer;
    }
    return $contents;
}

sub del_file {
    my $id = shift;
    my $db = Warewulf::DataStore->new();
    my $fSet = $db->get_objects('file','_id',($id));
    $db->del_object($fSet);
    $db->persist();
}


sub create_new_file {
    my $name = shift;
    my $uid = shift;
    my $gid = shift;
    my $mode = shift;
    my $path = shift;
    my $contents = shift;

    my $obj = Warewulf::DSOFactory->new("file");
    my $db = Warewulf::DataStore->new();
    $db->persist($obj);
    $obj->set('name',$name);
    $obj->set('uid',$uid);
    $obj->set('gid',$gid);
    $obj->set('mode',$mode);
    $obj->set('path',$path);
    $obj->set('format','data');
    $db->persist($obj);
    my $id = $obj->get('_id');
    set_file_contents($id,$contents);
    return files_hash($db->get_objects('file','_id',($id)));
}

sub set_file_contents {
    my $id = shift;
    my $contents = shift;
    eval {
    my $db = Warewulf::DataStore->new();
    my $binstore = $db->binstore($id);
    my $file = ($db->get_objects('file','_id',($id)))->get_object(0);

    my $rstring = map { ("a".."z")[rand 26] } (1..8); 
    my $rname = "/tmp/wwsh.$rstring";

    open (TMPFILE, ">$rname") or die "Couldn't open $rname for writing";
    print TMPFILE $contents;
    close(TMPFILE);

    my $checksum = digest_file_hex_md5($rname);
    my $size = 0;
    my $buffer;

    open(FILE,$rname) or die "couldn't open $rname for reading";
    while( my $length = sysread(FILE,$buffer,$db->chunk_size) ) {
        $binstore->put_chunk($buffer);
        $size += $length;
    }
    close(FILE);
    
    $file->set('size',$size);
    $file->set('checksum',$checksum);
    $db->persist($file);
    return 1;
    } or do {
        print "Error! $@\n";
        return $@;
    };
}



# set_file_properties
#   Like set_node_properties, take a hash
#
#   $props{$id}{'gid'} = "<gid>";
#   $props{$id}{'name'} = "<name>";
#   etc.
sub set_file_properties {
    my $href = shift;
    my %props = %{$href};

    my $db = Warewulf::DataStore->new();
    my @idlist;
    
    foreach my $id (keys %props) {
        push(@idlist,$id);
        my $f = ( ($db->get_objects('file','_id',($id)))->get_list() )[0];
        foreach my $p (keys %{ $props{$id} }) {
            if ( ref($props{$id}{$p} =~ /^ARRAY/ ) ) {
                my @aref = @{ $props{$id}{$p} };
                $f->set($p,@aref);
            } else {
                $f->set($p,$props{$id}{$p});
            }
        }
        $db->persist($f);
    }

    my $fSet = $db->get_objects('file','_id',@idlist);
    return files_hash($fSet);
}


sub files_hash {
    my $fileSet = shift;
    my %result;
    foreach my $file ($fileSet->get_list()) {
        my $id = $file->get('_id');
        $result{$id}{'_id'} = $id;
        my %hash = $file->get_hash();
        foreach my $k (keys %hash) {
            $result{$id}{lc($k)} = $hash{$k}
        }

    }
    return %result;
}

