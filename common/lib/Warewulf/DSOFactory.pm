# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: DSOFactory.pm 83 2010-12-09 22:13:21Z gmk $
#

package Warewulf::DSOFactory;

use Warewulf::Util;
use Warewulf::Logger;
use Warewulf::DSO;
use DBI;

my %modules;

=head1 NAME

Warewulf::DSOFactory - This will automatically load the appropriate DSO
(Data Store Object) on an as needed basis.

=head1 ABOUT


=head1 SYNOPSIS

    use Warewulf::DSOFactory;

    my $obj = Warewulf::DSOFactory->new($type);

=item new()

Create the object.

=cut
sub
new($$)
{
    my $proto = shift;
    my $type = uc(shift);
    my $mod_name = "Warewulf::DSO::". ucfirst(lc($type));

    if (! exists($modules{$mod_name})) {
        &dprint("Loading object name: $mod_name\n");
        eval "require $mod_name";
        if ($@) {
            &wprint("Could not load '$mod_name', returning a DSO baseclass object!\n");
            return(Warewulf::DSO->new(\@_));
        }
        $modules{$mod_name} = 1;
    }

    &dprint("Getting a new object from $mod_name\n");

    my $obj = eval "$mod_name->new(\@_)";

    &dprint("Got an object: $obj\n");

    return($obj);
}

=back

=head1 SEE ALSO

Warewulf::Object, Warewulf::ObjectSet

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut

1;

