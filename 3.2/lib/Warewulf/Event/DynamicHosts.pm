# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: DynamicHosts.pm 50 2010-11-02 01:15:57Z gmk $
#

package Warewulf::Event::DynamicHosts;

use Warewulf::Logger;
use Warewulf::Event;
use Warewulf::EventHandler;
use Warewulf::Provision::HostsFile;


my $event = Warewulf::EventHandler->new();
my $obj = Warewulf::Provision::HostsFile->new();


sub
update_hosts()
{
    $obj->update_datastore(@_);
}


$event->register("node.add", \&update_hosts);
$event->register("node.delete", \&update_hosts);
$event->register("node.modify", \&update_hosts);

1;
