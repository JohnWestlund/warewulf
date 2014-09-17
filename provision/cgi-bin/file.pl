#!/usr/bin/perl
#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#


use CGI;
use Digest::MD5 ('md5_hex');
use File::Path;
use IPC::Open2;
use Warewulf::DataStore;
use Warewulf::Logger;
use Warewulf::Daemon;
use Warewulf::Node;
use Warewulf::File;
use Warewulf::DSO::File;
use Warewulf::Util;

&daemonized(1);
&set_log_level("WARNING");

my $q = CGI->new();
my $db = Warewulf::DataStore->new();

my $tmpdir = "/tmp/warewulf";
my $hwaddr = $q->param('hwaddr');
my $fileid = $q->param('fileid');
my $timestamp = $q->param('timestamp');
my @nodes;
my ($node, $oSet, $nodeName, $read_buffer, $send_buffer, $fileObj, $fileID, $fileName, $cachedir, $cachefile);

if ((! -d $tmpdir) && !mkpath($tmpdir, 0, 0750)) {
    &eprint("Unable to create temporary directory \"$tmpdir\" -- $!\n");
    exit(-1);
}

if ($hwaddr =~ /^([a-zA-Z0-9:]+)$/) {
    $hwaddr = $1;
} else {
    &wprint("HWADDR \"$hwaddr\" contains invalid character(s)\n");
    $q->print("Content-Type: application/octet-stream\r\n");
    $q->print("Status: 404\r\n");
    $q->print("\r\n");
    exit(0);
}

$oSet = $db->get_objects("node", "_hwaddr", $hwaddr);
@nodes = grep { $_->enabled() } $oSet->get_list();
if (scalar(@nodes) != 1) {
    &wprintf("HWADDR \"$hwaddr\" not found or not unique (%d found)\n", scalar(@nodes));
    $q->print("Content-Type: application/octet-stream\r\n");
    $q->print("Status: 404\r\n");
    $q->print("\r\n");
    exit(0);
}

$node = $nodes[0];
$nodeName = $node->name();
if (! $fileid) {
    my @files = $node->get("fileids");

    print $q->header("text/plain");
    if (scalar(@files)) {
        my $objSet = $db->get_objects("file", "_id", @files);
        my %metadata;

        foreach my $obj ($objSet->get_list()) {
            my ($obj_id, $obj_name) = ($obj->id(), $obj->name() || "NULL");
            my ($obj_ts, $obj_uid, $obj_gid);

            if (ref($obj) ne "Warewulf::File") {
                &wprintf("Object $obj_id ($obj_name) provisioned to $nodeName ($hwaddr) is a(n) %s; should be Warewulf::File!\n",
                         ref($obj));
                next;
            }
            ($obj_ts, $obj_uid, $obj_gid, $obj_ftype) = ($obj->timestamp(), $obj->uid(), $obj->gid(), $obj->filetypestring());

            if ($timestamp && $timestamp >= $obj_ts) {
                next;
            }
            $metadata{$obj_ts} .= sprintf("$obj_id $obj_name $obj_uid $obj_gid %s%04o $obj_ts %s\n",
                                          (($obj_ftype eq '-') ? (' ') : ($obj_ftype)),
                                          $obj->mode(), $obj->path() || "NULL");
        }
        print map { $metadata{$_} } sort { $a <=> $b } keys(%metadata);
    }
    exit(0);
} elsif ($fileid =~ /^([0-9]+)$/ ) {
    $fileid = $1;
} else {
    # A file ID was given, but its an invalid ID.  This needs to error out on
    # the client so that the client doesn't overwrite the target file.
    $fileid =~ s/[^[:print:]]//g;
    &wprint("Requested File ID \"$fileid\" contains invalid characters (requested by: $nodeName/$hwaddr)\n");
    $q->print("Content-Type: application/octet-stream\r\n");
    $q->print("Status: 404\r\n");
    $q->print("\r\n");
    exit(0);
}

if (!($fileObj = $db->get_objects("file", "_id", $fileid)->get_object(0))) {
    &wprint("Requested File ID \"$fileid\" does not exist (requested by: $nodeName/$hwaddr)\n");
    $q->print("Content-Type: application/octet-stream\r\n");
    $q->print("Status: 400\r\n");
    $q->print("\r\n");
    exit(0);
} elsif (ref($fileObj) ne "Warewulf::File") {
    &wprintf("Object $fileid (%s) provisioned to $nodeName ($hwaddr) is a(n) %s; should be Warewulf::File!\n",
             $fileObj->name(), ref($fileObj));
    $q->print("Content-Type: application/octet-stream\r\n");
    $q->print("Status: 400\r\n");
    $q->print("\r\n");
    exit(0);
}

$fileID = $fileObj->id();
$fileName = $fileObj->name();
$cachedir = "$tmpdir/files/$fileID/";
$cachefile = "$cachedir/". $fileObj->checksum();

# Initially cache the file if it doesn't already exist locally
if (! -f $cachefile) {
    if (! -d $cachedir && !mkpath($cachedir, 0, 0770)) {
        &eprint("Unable to create cache directory \"$cachedir\" -- $!\n");
        exit(-1);
    }
    $fileObj->file_export($cachefile);
}

# Make sure checksum exists before going forward. Otherwise we will remove cached
# file below, and send an internal error to the client.
if (&digest_file_hex_md5($cachefile) ne $fileObj->checksum()) {
    unlink($cachefile);
    &eprint("File $fileID ($fileName) checksum from data store does not match cached copy; unlinking.\n");
    $q->print("Content-Type: application/octet-stream\r\n");
    $q->print("Status: 500\r\n");
    $q->print("\r\n");
    exit(-1);
}
if (open(CACHE, $cachefile)) {
    my @statinfo = stat($cachefile);

    if (sysread(CACHE, $read_buffer, $statinfo[7]) < $statinfo[7]) {
        unlink($cachefile);
        &eprint("Error reading from cache file $cachefile for file $fileID ($fileName) -- $!; unlinking.\n");
        $q->print("Content-Type: application/octet-stream\r\n");
        $q->print("Status: 500\r\n");
        $q->print("\r\n");
        exit(-1);
    }
    close CACHE;
} else {
    unlink($cachefile);
    &eprint("Error opening cache file $cachefile for file $fileID ($fileName) -- $!; unlinking.\n");
    $q->print("Content-Type: application/octet-stream\r\n");
    $q->print("Status: 500\r\n");
    $q->print("\r\n");
    exit(-1);
}

# Search for all matching variable entries.
foreach my $wwstring ($read_buffer =~ m/\%\{[^\}]+\}(?:\[\d+\])?/g) {
    # Check for format, and separate into a separate wwvar string
    if ($wwstring =~ /^\%\{(.+?)\}(\[(\d+)\])?$/) {
        # Set the current object that we are looking at. This is
        # important as we iterate through multiple levels.
        my $curObj = $node;
        my ($wwvar, $wwarrayindex) = ($1, $3);
        my @keys = split(/::/, $wwvar);

        while (my $key = shift(@keys)) {
            my $val = $curObj->get($key);

            if (ref($val) eq "Warewulf::ObjectSet") {
                my $find = shift(@keys);
                my $o = $val->find("name", $find);

                if ($o) {
                    $curObj = $o;
                } else {
                    &dprint("Could not find object:  $find\n");
                }
            } elsif (ref($val) eq "ARRAY") {
                my $v;

                if ($wwarrayindex) {
                    $v = $val->[$wwarrayindex];
                } else {
                    $v = $val->[0];
                }
                $read_buffer =~ s/\Q$wwstring\E/$v/g;
            } elsif (defined($val)) {
                $read_buffer =~ s/\Q$wwstring\E/$val/g;
            } else {
                $read_buffer =~ s/\Q$wwstring\E//g;
            }
        }
    }
}

if ($fileObj->interpreter()) {
    my $interpreter = $fileObj->interpreter();
    my ($pipe_in, $pipe_out);

    eval {
        my $pid;
        local $SIG{ALRM} = sub { die "File $fileID ($fileName) timed out on running intrepreter '$interpreter'\n" };

        alarm(1);
        if (($pid = open2($pipe_out, $pipe_in, "$interpreter"))) {
            print $pipe_in $read_buffer;
            close $pipe_in;
            while (my $line = <$pipe_out>) {
                $send_buffer .= $line;
            }
            close $pipe_out;
            waitpid($pid, 0);
        }
        alarm(0);
    };
    if ($@) {
        &eprint("FileID ($fileid) failed running interpreter '$intrepreter'\n");
        $send_buffer = undef;
    }
} elsif ($read_buffer) {
    $send_buffer = $read_buffer;
}

if ($send_buffer) {
    $q->print("Content-Type: application/octet-stream\r\n");
    $q->print("Content-Disposition: attachment\r\n");
    $q->print("\r\n");

    print $send_buffer;
}
