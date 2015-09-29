package Warewulf::Module::EasyFuncs::Util;

use Warewulf::DataStore;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(get_name_by_id get_id_by_name);

sub get_name_by_id {
    my $type = shift;
    my $id = shift;
    my $db = Warewulf::DataStore->new();
    my $objectSet = $db->get_objects($type,'_id',($id));
    if ( $objectSet->count() < 1 ) {
        return undef;
    } 
    return ($objectSet->get_object(0))->get('name');
}

sub get_id_by_name {
    my $type = shift;
    my $name = shift;
    my $db = Warewulf::DataStore->new();
    my $objectSet = $db->get_objects($type,'name',($name));
    if ( $objectSet->count() != 1 ) {
        return undef;
    }
    return ($objectSet->get_object(0))->get('_id');
}
