# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#

package Warewulf::Provision;

use Warewulf::Object;
use Warewulf::Logger;
use Warewulf::DataStore;
use Warewulf::Util;
use Warewulf::Node;

our @ISA = ('Warewulf::Object');

push(@Warewulf::Node::ISA, 'Warewulf::Provision');

=head1 NAME

Warewulf::Provision - Provision object class for Warewulf

=head1 ABOUT

Object class for extending the Node objects for provisioning.

=head1 SYNOPSIS

    use Warewulf::Node;
    use Warewulf::Provision;

    my $obj = Warewulf::Node->new();

=head1 METHODS

=over 12

=cut



=item bootstrapid($string)

Set or return the bootstrap ID for this node

=cut

sub
bootstrapid()
{
    my $self = shift;

    return $self->prop("bootstrapid", qr/^([0-9]+)$/, @_);
}


=item vnfsid($string)

Set or return the VNFS ID for this node

=cut

sub
vnfsid()
{
    my $self = shift;

    return $self->prop("vnfsid", qr/^([0-9]+)$/, @_);
}

=item vnfs($string)

Return the name of the VNFS this node is configured to use

=cut

sub
vnfs()
{
    my $self = shift;
    my $db = Warewulf::DataStore->new();

    my $vnfsid = $self->vnfsid();
    my $vnfs = $db->get_objects("vnfs", "_id", $vnfsid)->get_object(0);

    use Data::Dumper;
    print "\n ---- \$vnfsid ---- \n" . "  \$vnfsid = $vnfsid" . "\n -------- \n";
    print "\n ---- vnfs ---- \n" . Dumper($vnfs) . "\n -------- \n";

    # Can't do $vnfs->name() || "UNDEF" ... because if it fails on pulling an
    # object, then the name() sub doesn't exist.
    if ($vnfs) {
        return $vnfs->name();
    } else {
        return "UNDEF";
    }
}

=item fileids(@fileids)

Set or return the list of file ID's to be provisioned for this node

=cut

sub
fileids()
{
    my ($self, @strings) = @_;
    my $key = "fileids";

    if (@strings) {
        my $name = $self->get("name");
        my @new;
        foreach my $string (@strings) {
            if ($string =~ /^([0-9]+)$/) {
                &dprint("Object $name set $key += '$1'\n");
                push(@new, $1);
            } else {
                &eprint("Invalid characters to set $key += '$string'\n");
            }
            $self->set($key, @new);
        }
    }

    return($self->get($key));
}

=item kargs()

Set or return the list of kernel arguments. If an array element
includes whitespace (i.e. it includes multiple kernel arguments),
split it and store it as separate array elements.

=cut

sub 
kargs()
{
    my ($self, @strings) = @_;
    my $key = "kargs";

    if (uc($strings[0]) eq "UNDEF") {
        $self->del($key);
        return $self->get($key);
    }

    if (@strings) {
        my $name = $self->get("name");
        my @new;
        foreach my $string (@strings) {
            my @kargs = split(/\s+/,$string); # pre-emptively split
            foreach my $karg (@kargs) {
                &dprint("Object $name set $key +=' $karg'\n");
                push(@new,$karg);
            }
        }
        $self->set($key,@new);
    }

    return $self->get($key);
}

=item fileidadd(@fileids)

Add a file ID or list of file IDs to the current object.

=cut

sub
fileidadd()
{
    my ($self, @strings) = @_;
    my $key = "fileids";

    if (@strings) {
        my $name = $self->get("name");
        foreach my $string (@strings) {
            if ($string =~ /^([0-9]+)$/) {
                &dprint("Object $name set $key += '$1'\n");
                $self->add($key, $1);
            } else {
                &eprint("Invalid characters to set $key += '$string'\n");
            }
        }
    }

    return($self->get($key));
}


=item fileiddel(@fileids)

Delete a file ID or list of file IDs to the current object.

=cut

sub
fileiddel()
{
    my ($self, @strings) = @_;
    my $key = "fileids";

    if (@strings) {
        my $name = $self->get("name");
        $self->del($key, @strings);
        &dprint("Object $name del $key -= @strings\n");
    }

    return($self->get($key));
}


=item master(@strings)

Set or return the master of this object.

=cut

sub
master()
{
    my ($self, @strings) = @_;
    my $key = "master";
    my @masters;

    if (@strings) {
        if (uc($strings[0]) eq "UNDEF") {
            &dprint("Object $name del $key\n");
            $self->del($key);
        } else {
            my $name = $self->get("name");
            foreach my $string (@strings) {
                if ($string =~ /^(\d+\.\d+\.\d+\.\d+)$/) {
                    push(@masters, $1);
                } else {
                    &eprint("Invalid characters to set $key = '$string'\n");
                }
            }
            &dprint("Object $name set $key = @masters\n");
            $self->set($key, @masters);
        }
    }

    return $self->get($key);
}


=item preshell($bool)

Set or return the preshell boolean

=cut

sub
preshell()
{
    my ($self, $bool) = @_;

    if (defined($bool)) {
        if ($bool) {
            $self->set("preshell", 1);
        } else {
            $self->del("preshell");
        }
    }

    return $self->get("preshell");
}


=item postshell($bool)

Set or return the postshell boolean

=cut

sub
postshell()
{
    my ($self, $bool) = @_;

    if (defined($bool)) {
        if ($bool) {
            $self->set("postshell", 1);
        } else {
            $self->del("postshell");
        }
    }

    return $self->get("postshell");
}


=item bootlocal($bool)

Set or return the bootlocal boolean

=cut

sub
bootlocal()
{
    my ($self, $bool) = @_;

    if (defined($bool)) {
        if ($bool) {
            $self->set("bootlocal", 1);
        } else {
            $self->del("bootlocal");
        }
    }

    return $self->get("bootlocal");
}

=back

=head1 SEE ALSO

Warewulf::Object Warewulf::DSO::Node

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
