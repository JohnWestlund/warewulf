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
use Warewulf::SystemFactory;
use Warewulf::Util;
use Warewulf::DSOFactory;


=head1 NAME

Warewulf::Provision::HostsFile - Generate a basic hosts file from the Warewulf
datastore.

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
        my $nodename = $n->get("fqdn") || $n->get("name");
        my $cluster = $n->get("cluster");
        my $domain = $n->get("domain");
        my $master_ipv4_addr = $netobj->ip_unserialize($master_ipv4_bin);
        my $default_name;

        &dprint("Evaluating node: $nodename\n");

        if (! defined($nodename)) {
            next;
        }

        foreach my $d ($n->get("netdevs")) {
            if (ref($d) eq "Warewulf::DSO::Netdev") {
                my ($netdev) = $d->get("name");
                my ($ipv4_bin) = $d->get("ipaddr");
                if ($netdev and $ipv4_bin) {
                    my $ipv4_addr = $netobj->ip_unserialize($ipv4_bin);
                    my $node_network = $netobj->calc_network($ipv4_addr, $netmask);
                    my $fqdn = $d->get("fqdn");
                    my @name_entries;
                    my $name_eth;
                    my $multiple_dots;

                    if (($node_network eq $network) and ! defined($default_name)) {
                        $name_eth = $nodename;
                        $default_name = 1;
                    } else {
                        $name_eth = "$nodename-$netdev";
                    }

                    if (defined($fqdn)) {
                        push(@name_entries, sprintf("%-18s", "$fqdn"));
                        $multiple_dots = 1;
                    }

                    push(@name_entries, sprintf("%-12s", $name_eth));

                    if (defined($cluster) and defined($domain)) {
                        push(@name_entries, sprintf("%-18s", "$name_eth.$cluster.$domain"));
                        $multiple_dots = 1;
                    }
                    if (defined($cluster)) {
                        push(@name_entries, sprintf("%-18s", "$name_eth.$cluster"));
                        $multiple_dots = 1;
                    }
                    if (defined($domain)) {
                        push(@name_entries, sprintf("%-18s", "$name_eth.$domain"));
                        $multiple_dots = 1;
                    }

                    if (! $multiple_dots) {
                        push(@name_entries, sprintf("%-18s", "$name_eth.localdomain"));
                    }

                    if ($nodename and $ipv4_addr) {
                        &dprint("Adding a host entry for: $nodename-$netdev\n");

                        $hosts .= sprintf("%-23s %s\n", $ipv4_addr, join(" ", @name_entries));
                    }

                } else {
                    &dprint("Node '$nodename' has an invalid netdevs entry!\n");
                }
            }
        }
    }

    return($hosts);
}

print &generate() ."\n\n";


=item update_datastore()

Update the Warewulf datastore with the current hosts file.

=cut
sub
update_datastore()
{
    my $self = shift;
    my $name = "dynamic_hosts";
    my $datastore = Warewulf::DataStore->new();

    &dprint("Updating datastore\n");

    my $hosts = $self->generate();
    my $len = length($hosts);

    &dprint("Getting file object for '$name'\n");
    my $fileobj = $datastore->get_objects("file", "name", $name)->get_object(0);

    if (! $fileobj) {
        $fileobj = Warewulf::DSOFactory->new("file");
        $fileobj->set("name", $name);
    }

    my $binstore = $datastore->binstore($fileobj->get("_id"));

    $fileobj->set("checksum", md5_hex($hosts));
    $fileobj->set("path", "/etc/hosts");
    $fileobj->set("format", "data");
    $fileobj->set("length", $len);
    $fileobj->set("uid", "0");
    $fileobj->set("gid", "0");
    $fileobj->set("mode", "0644");

    $datastore->persist($fileobj);

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
