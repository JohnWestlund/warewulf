# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#########################
# Copyright (c) 2013, Intel(R) Corporation #{
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#    * Redistributions of source code must retain the above copyright notice,
#      this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#    * Neither the name of Intel(R) Corporation nor the names of its
#      contributors may be used to endorse or promote products derived from
#      this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#########################}
#

package Warewulf::Gres::MIC;

use Warewulf::Logger;
use Warewulf::Object;
use Warewulf::Node;

our @ISA = ('Warewulf::Object');

push(@Warewulf::Node::ISA, 'Warewulf::Gres::MIC');

=head1 NAME

Warewulf::Gres::MIC - Warewulf's Intel(R) Xeon Phi(TM) interface.

=head1 SYNOPSIS

    use Warewulf::Node;
    use Warewulf::Gres::MIC;

    my $obj = Warewulf::Node->new();
    $obj->name("test0000");

    # Set the node to have two (2) Xeon Phi(TM) Cards
    $obj->miccount(2);

=head1 DESCRIPTION

The C<Warewulf::Gres::MIC> package contains the Intel(R) Xeon Phi(TM)
extension for a C<Warewulf::Node> object.

=head1 METHODS

=over 4

=item miccount($devices)

Get or set the number of MIC cards on a given host.

=cut

sub
miccount()
{
    my $self = shift;
    my $count = $self->prop("miccount", qr/^([0-9]+)$/, @_);

    if (scalar(@_) && defined($_[0])) {
        &dprint("Set number of MIC devices to: $_[0]\n");
    }

    return $count;
}

=back

=head1 SEE ALSO

Warewulf::Object Warewulf::Node

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.
 
Copyright (c) 2013, Intel(R) Corporation

=cut

1;

# vim:filetype=perl:syntax=perl:expandtab:ts=4:sw=4:
