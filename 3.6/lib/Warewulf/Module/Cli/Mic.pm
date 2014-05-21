#
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


package Warewulf::Module::Cli::Mic;

use Warewulf::Config;
use Warewulf::Logger;
use Warewulf::Module::Cli;
use Warewulf::Term;
use Warewulf::DataStore;
use Warewulf::Util;
use Warewulf::Node;
use Warewulf::DSO::Node;
use Warewulf::GRes::MIC;
use Warewulf::Network;
use Getopt::Long;
use Text::ParseWords;

our @ISA = ('Warewulf::Module::Cli');

my $entity_type = "node";

sub
new()
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};

    bless($self, $class);

    $self->init();

    return $self;
}

sub
init()
{
    my ($self) = @_;

    $self->{"DB"} = Warewulf::DataStore->new();
}


sub
help()
{
    my $h;
    my $config_defaults = Warewulf::Config->new("defaults/node.conf");
    my $netdev = $config_defaults->get("netdev") || "UNDEF";

    $h .= "USAGE:\n";
    $h .= "     mic <command> [options] [targets]\n";
    $h .= "\n";
    $h .= "SUMMARY:\n";
    $h .= "     The mic command is used for viewing and manipulating Intel(R)\n";
    $h .= "     Xeon Phi(TM) settings on node objects.\n";
    $h .= "\n";
    $h .= "COMMANDS:\n";
    $h .= "         set             Modify existing settings\n";
    $h .= "         print           Print the node configuration\n";
    $h .= "         help            Show usage information\n";
    $h .= "\n";
    $h .= "TARGETS:\n";
    $h .= "     The target(s) specify which node(s) will be affected by the chosen\n";
    $h .= "     action(s).  By default, node(s) will be identified by their name(s).\n";
    $h .= "     Use the --lookup option to specify another property (e.g., \"hwaddr\"\n";
    $h .= "     or \"groups\").\n";
    $h .= "\n";
    $h .= "     All targets can be bracket expanded as follows:\n";
    $h .= "\n";
    $h .= "         n00[0-99]       All nodes from n0000 through n0099 (inclusive)\n";
    $h .= "         n00[00,10-99]   n0000 and all nodes from n0010 through n0099\n";
    $h .= "\n";
    $h .= "OPTIONS:\n";
    $h .= "     -l, --lookup        Identify nodes by specified property (default: \"name\")\n";
    $h .= "         --mic           Set the number of MIC devices on this node\n";
    $h .= "\n";
    $h .= "EXAMPLES:\n";
    $h .= "     Warewulf> mic set n0000 --mic=2\n";
    $h .= "     Warewulf> mic set n0000 --mic=0\n";
    $h .= "     Warewulf> mic set --lookup=groups phi2 --mic=2\n";
    $h .= "     Warewulf> mic print\n";
    $h .= "\n";

    return ($h);
}

sub
summary()
{
    my $output;

    $output .= "Intel(R) Xeon Phi(TM) manipulation commands";

    return ($output);
}



sub
complete()
{
    my $self = shift;
    my $opt_lookup = "name";
    my $db = $self->{"DB"};
    my @ret;

    if (! $db) {
        return;
    }

    @ARGV = ();

    foreach (&quotewords('\s+', 0, @_)) {
        if (defined($_)) {
            push(@ARGV, $_);
        }
    }

    Getopt::Long::Configure ("bundling", "passthrough");

    GetOptions(
        'l|lookup=s'    => \$opt_lookup,
    );

    if (exists($ARGV[1]) and ($ARGV[1] eq "print" or $ARGV[1] eq "set")) {
        @ret = $db->get_lookups($entity_type, $opt_lookup);
    } else {
        @ret = ("print", "set");
    }

    @ARGV = ();

    return (@ret);
}

sub
exec()
{
    my $self = shift;
    my $db = $self->{"DB"};
    my $term = Warewulf::Term->new();
    my $config_defaults = Warewulf::Config->new("defaults/node.conf");
    my $opt_netdev = $config_defaults->get("netdev");
    my $opt_lookup = "name";
    my $opt_mic;
    my @opt_print;
    my $return_count;
    my $objSet;
    my @changes;
    my $command;
    my $object_count = 0;
    my $persist_count = 0;

    @ARGV = ();
    push(@ARGV, @_);

    Getopt::Long::Configure ("bundling", "nopassthrough");

    GetOptions(
        'mic=s'         => \$opt_mic,
        'l|lookup=s'    => \$opt_lookup,
    );

    $command = shift(@ARGV);

    if (! $db) {
        &eprint("Database object not avaialble!\n");
        return undef;
    }

    if (! $command) {
        &eprint("You must provide a command!\n\n");
        print $self->help();
        return undef;
    } else {
        if ($opt_lookup eq "hwaddr") {
            $opt_lookup = "_hwaddr";
        } elsif ($opt_lookup eq "id") {
            $opt_lookup = "_id";
        }
        $objSet = $db->get_objects($opt_type || $entity_type, $opt_lookup, &expand_bracket(@ARGV));
    }

    if ($objSet) {
        $object_count = $objSet->count();
    }
    if (! $objSet || ($object_count == 0)) {
        &nprint("No nodes found to work with\n");
        return undef;
    }

    if ($command eq "print") {
        foreach my $o ($objSet->get_list()) {
            my $nodename = $o->name() || "UNDEF";

            &nprintf("#### %s %s#\n", $nodename, "#" x (72 - length($nodename)));
            printf("%15s: %-16s = %s\n", $nodename, "MICCOUNT", $o->miccount() || "UNDEF");
            $return_count++;
        }
    } elsif ($command eq "set") {
        if (defined $opt_mic) {
            if ($opt_mic =~ /^([0-9]+)$/) {
                my $show_changes;
                foreach my $obj ($objSet->get_list()) {
                    $obj->miccount($opt_mic);
                    $persist_count++;
                    $show_changes = 1;

                    my $nodename = $obj->get("name") || "UNDEF";
                    &dprint("Setting miccount=$opt_mic in $nodename\n");
                }

                if ($show_changes) {
                    push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "MICCOUNT", $opt_mic));
                }
            } else {
                &eprint("Option 'mic' has invalid characters\n");
            }
        }

        if ($persist_count > 0) {
            if ($term->interactive()) {
                my $node_count = $objSet->count();
                my $question;

                $question = sprintf("Are you sure you want to make the following %d change(s) to %d node(s):\n\n",
                                    $persist_count, $node_count);
                $question .= join('', @changes) . "\n";
                if (! $term->yesno($question)) {
                    &nprint("No update performed\n");
                    return undef;
                }
            }

            $return_count = $db->persist($objSet);

            &iprint("Updated $return_count objects\n");
        }

    } elsif ($command eq "help") {
        print $self->help();

    } else {
        &eprint("Unknown command: $command\n\n");
        print $self->help();
    }

    # We are done with ARGV, and it was internally modified, so lets reset
    @ARGV = ();

    return $return_count;
}

1;
# vim:filetype=perl:syntax=perl:expandtab:ts=4:sw=4:
