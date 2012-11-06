# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: HostsFile.pm 50 2010-11-02 01:15:57Z gmk $
#

package Warewulf::Provision::HostsFile;

use Socket;
use Digest::MD5 qw(md5_hex);
use Warewulf::ACVars;
use Warewulf::Logger;
use Warewulf::Provision::Dhcp;
use Warewulf::DataStore;
use Warewulf::Network;
use Warewulf::Node;
use Warewulf::SystemFactory;
use Warewulf::Util;
use Warewulf::File;
use Warewulf::DSO::File;


=head1 NAME

Warewulf::Provision::HostsFile - Generate a basic hosts file from the Warewulf
data store.

=head1 ABOUT


=head1 SYNOPSIS

    use Warewulf::Provision::HostsFile;

    my $obj = Warewulf::Provision::HostsFile->new();
    my $string = $obj->generate();


=head1 METHODS

=over 12

=cut

=item new()

The new constructor will create the object that references configuration the
stores.

=cut

sub
new($$)
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = ();

    $self = {};

    bless($self, $class);

    return $self->init(@_);
}


sub
init()
{
    my $self = shift;

    return($self);
}


=item generate()

This will generate the content of the /etc/hosts file.

=cut

sub
generate()
{
    my $self = shift;
    my $datastore = Warewulf::DataStore->new();
    my $netobj = Warewulf::Network->new();
    my $config = Warewulf::Config->new("provision.conf");
    my $sysconfdir = &Warewulf::ACVars::get("sysconfdir");

    my $netdev = $config->get("network device");
    my $ipaddr = $netobj->ipaddr($netdev);
    my $netmask = $netobj->netmask($netdev);
    my $network = $netobj->network($netdev);

    my $hosts;

    if (! -f "$sysconfdir/warewulf/hosts-template") {
        open(HOSTS, "> $sysconfdir/warewulf/hosts-template");
        print HOSTS "# Host file template dynamically generated by Warewulf\n";
        print HOSTS "127.0.0.1               localhost localhost.localdomain localhost4 localhost4.localdomain4\n";
        print HOSTS "::1                     localhost localhost.localdomain localhost6 localhost6.localdomain4\n";
        print HOSTS "\n";
        close(HOSTS);
    }

    open(HOSTS, "$sysconfdir/warewulf/hosts-template");
    while(my $line = <HOSTS>) {
        $hosts .= $line;
    }
    close(HOSTS);

    foreach my $n ($datastore->get_objects("node")->get_list()) {
        my $nodename = $n->name();
        my $master_ipv4_addr = $netobj->ip_unserialize($master_ipv4_bin);
        my $default_name;

        if (! defined($nodename)) {
            next;
        }

        &dprint("Evaluating node: $nodename\n");

        foreach my $devname ($n->netdevs_list()) {
            my $node_ipaddr = $n->ipaddr($devname);
            my $node_fqdn = $n->fqdn($devname);
            my $node_testnetwork;
            my @name_entries;

            if (! $node_ipaddr) {
                &dprint("Skipping $devname as it has no defined IPADDR\n");
                next;
            }

            $node_testnetwork = $netobj->calc_network($node_ipaddr, $netmask);

            if ($node_fqdn) {
                push(@name_entries, $node_fqdn);
            }

            if (($node_testnetwork eq $network) and ! defined($default_name)) {
                $default_name = 1;
                if (! $n->domain() and ! $n->cluster()) {
                    push(@name_entries, $n->nodename() .".localcluster");
                }
                push(@name_entries, reverse $n->name());
            }

            foreach my $name (reverse $n->name()) {
                &dprint("Adding a name_entry for '$name-$devname'\n");
                push(@name_entries, "$name-$devname");
            }

            if ($node_ipaddr and @name_entries) {
                $hosts .= sprintf("%-23s %s\n", $node_ipaddr, join(" ", @name_entries));
            } else {
                &iprint("Not writing a host entry for $nodename-$devname ($node_ipaddr)\n");
            }

        }
    }

    return($hosts);
}


=item update_datastore()

Update the Warewulf data store with the current hosts file.

=cut

sub
update_datastore()
{
    my $self = shift;
    my $binstore;
    my $name = "dynamic_hosts";
    my $datastore = Warewulf::DataStore->new();

    &dprint("Updating data store\n");

    my $hosts = $self->generate();
    my $len = length($hosts);

    &dprint("Getting file object for '$name'\n");
    my $fileobj = $datastore->get_objects("file", "name", $name)->get_object(0);

    if (! $fileobj) {
        $fileobj = Warewulf::File->new("file");
        $fileobj->set("name", $name);
    }

    $fileobj->checksum(md5_hex($hosts));
    $fileobj->path("/etc/hosts");
    $fileobj->format("data");
    $fileobj->size($len);
    $fileobj->uid("0");
    $fileobj->gid("0");
    $fileobj->mode(oct("0644"));

    $datastore->persist($fileobj);

    $binstore = $datastore->binstore($fileobj->id());

    my $read_length = 0;
    while($read_length != $len) {
        my $buffer = substr($hosts, $read_length, $datastore->chunk_size());
        $binstore->put_chunk($buffer);
        $read_length = length($buffer);
    }

}


=back

=head1 SEE ALSO

Warewulf::Provision::Dhcp

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;