# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#

package Warewulf::File;

use Warewulf::Object;
use Warewulf::Logger;
use Warewulf::DataStore;
use Warewulf::Util;
use File::Basename;
use File::Path;
use Digest::MD5 qw(md5_hex);



our @ISA = ('Warewulf::Object');

=head1 NAME

Warewulf::File - Warewulf's general object instance object interface.

=head1 ABOUT

This is the primary Warewulf interface for dealing with files within the
Warewulf DataStore.

=head1 SYNOPSIS

    use Warewulf::File;

    my $obj = Warewulf::File->new();

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

    $self = $class->SUPER::new();
    bless($self, $class);

    return $self->init(@_);
}


=item id()

Return the Database ID for this object.

=cut

sub
id()
{
    my ($self) = @_;

    return($self->get("_id") || "UNDEF");
}



=item name($string)

Set or return the name of this object. The string "UNDEF" will delete this
key from the object.

=cut

sub
name()
{
    my ($self, $string) = @_;
    my $key = "name";

    if (defined($string)) {
        if (uc($string) eq "UNDEF") {
            my $name = $self->get("name");
            &dprint("Object $name delete $key\n");
            $self->del($key);
        } elsif ($string =~ /^([a-zA-Z0-9_\.\-]+)$/) {
            my $name = $self->get("name") || "UNDEF";
            &dprint("Object $name set $key = '$1'\n");
            $self->set($key, $1);
        } else {
            &eprint("Invalid characters to set $key = '$string'\n");
        }
    }

    return($self->get($key) || "UNDEF");
}


=item mode($string)

Set the numeric permission "mode" of this file (e.g. 0644).

=cut

sub
mode()
{
    my ($self, $string) = @_;
    my $key = "mode";

    if (defined($string)) {
        if (uc($string) eq "UNDEF") {
            my $name = $self->get("name");
            &dprint("Object $name delete $key\n");
            $self->del($key);
        } elsif ($string =~ /^([0-7]{3,4})$/) {
            my $name = $self->get("name");
            &dprint("Object $name set $key = '$1'\n");
            $self->set($key, $1);
        } else {
            &eprint("Invalid characters to set $key = '$string'\n");
        }
    }

    return(sprintf("%04d", $self->get($key) || "0"));
}


=item checksum($string)

Set or get the checksum of this file.

=cut

sub
checksum()
{
    my ($self, $string) = @_;
    my $key = "checksum";

    if (defined($string)) {
        if (uc($string) eq "UNDEF") {
            my $name = $self->get("name");
            &dprint("Object $name delete $key\n");
            $self->del($key);
        } elsif ($string =~ /^([a-z0-9]+)$/) {
            my $name = $self->get("name");
            &dprint("Object $name set $key = '$1'\n");
            $self->set($key, $1);
        } else {
            &eprint("Invalid characters to set $key = '$string'\n");
        }
    }

    return($self->get($key) || "UNDEF");
}


=item uid($string)

Set or return the UID of this file.

=cut

sub
uid()
{
    my ($self, $string) = @_;
    my $key = "uid";

    if (defined($string)) {
        if (uc($string) eq "UNDEF") {
            my $name = $self->get("name");
            &dprint("Object $name delete $key\n");
            $self->del($key);
        } elsif ($string =~ /^(\d+)$/) {
            my $name = $self->get("name");
            &dprint("Object $name set $key = '$1'\n");
            $self->set($key, $1);
        } else {
            &eprint("Invalid characters to set $key = '$string'\n");
        }
    }

    return($self->get($key) || "0");
}


=item gid($string)

Set or return the GID of this file.

=cut

sub
gid()
{
    my ($self, $string) = @_;
    my $key = "gid";

    if (defined($string)) {
        if (uc($string) eq "UNDEF") {
            my $name = $self->get("name");
            &dprint("Object $name delete $key\n");
            $self->del($key);
        } elsif ($string =~ /^(\d+)$/) {
            my $name = $self->get("name");
            &dprint("Object $name set $key = '$1'\n");
            $self->set($key, $1);
        } else {
            &eprint("Invalid characters to set $key = '$string'\n");
        }
    }

    return($self->get($key) || "0");
}


=item size($string)

Set or return the size of the raw file stored within the datastore.

=cut

sub
size()
{
    my ($self, $string) = @_;
    my $key = "size";

    if (defined($string)) {
        if (uc($string) eq "UNDEF") {
            my $name = $self->get("name");
            &dprint("Object $name delete $key\n");
            $self->del($key);
        } elsif ($string =~ /^([0-9]+)$/) {
            my $name = $self->get("name");
            &dprint("Object $name set $key = '$1'\n");
            $self->set($key, $1);
        } else {
            &eprint("Invalid characters to set $key = '$string'\n");
        }
    }

    return($self->get($key) || "UNDEF");
}



=item path($string)

Set or return the target path of this file.

=cut

sub
path()
{
    my ($self, $string) = @_;
    my $key = "path";

    if (defined($string)) {
        if (uc($string) eq "UNDEF") {
            my $name = $self->get("name");
            &dprint("Object $name delete $key\n");
            $self->del($key);
        } elsif ($string =~ /^([a-zA-Z0-9_\.\-\/]+)$/) {
            my $name = $self->get("name");
            &dprint("Object $name set $key = '$1'\n");
            $self->set($key, $1);
        } else {
            &eprint("Invalid characters to set $key = '$string'\n");
        }
    }

    return($self->get($key) || "UNDEF");
}


=item format($string)

Set or return the format of this file.

=cut

sub
format()
{
    my ($self, $string) = @_;
    my $key = "format";

    if (defined($string)) {
        if (uc($string) eq "UNDEF") {
            my $name = $self->get("name");
            &dprint("Object $name delete $key\n");
            $self->del($key);
        } elsif ($string =~ /^([a-z]+)$/) {
            my $name = $self->get("name");
            &dprint("Object $name set $key = '$1'\n");
            $self->set($key, $1);
        } else {
            &eprint("Invalid characters to set $key = '$string'\n");
        }
    }

    return($self->get($key) || "UNDEF");
}



=item origin(@strings)

Set or return the origin(s) of this object.

=cut

sub
origin()
{
    my ($self, @strings) = @_;
    my $key = "origin";

    if (@strings) {
        my $name = $self->get("name");
        my @newgroups;
        foreach my $string (@strings) {
            if ($string =~ /^([a-zA-Z0-9_\.\-\/]+)$/) {
                &dprint("Object $name set $key += '$1'\n");
                push(@newgroups, $1);
            } else {
                &eprint("Invalid characters to set $key += '$string'\n");
            }
            $self->set($key, @newgroups);
        }
    }

    return($self->get($key));
}


=item sync()

Resync any file objects to their origin(s) on the local file system. This will
persist immeadiatly to the DataStore.

Note: This will also update some metadata for this file.

=cut

sub
sync()
{
    my ($self) = @_;
    my $name = $self->name();
    
    if ($self->origin()) {
        my $data;

        &dprint("Syncing file object: $name\n");

        foreach my $origin ($self->origin()) {
            if ($origin =~ /^(\/[a-zA-Z0-9\-_\/\.]+)$/) {
                if (-f $origin) {
                    if (open(FILE, $origin)) {
                        &dprint("   Including file to sync: $origin\n");
                        while(my $line = <FILE>) {
                            $data .= $line;
                        }
                        close FILE;
                    } else {
                        &wprint("Could not open origin ($origin) for file object '$name'\n");
                    }
                }
            }

        }

        if ($data) {
            my $db = Warewulf::DataStore->new();
            my $binstore = $db->binstore($self->id());
            my $total_len = length($data);
            my $cur_len = 0;
            my $start = 0;

            &dprint("Persisting file object '$name' origins\n");

            while($total_len > $cur_len) {
                my $buffer = substr($data, $start, $db->chunk_size());
                $binstore->put_chunk($buffer);
                $start += $db->chunk_size();
                $cur_len += length($buffer);
                &dprint("Chunked $cur_len of $total_len\n");
            }

            $self->checksum(md5_hex($data));
            $self->size($total_len);
            $db->persist($self);
        }

    } else {
        &dprint("Skipping file objct '$name' as it has no origins set\n");
    }
}


=item file_import($file)

Import a file at the defined path into the datastore directly. This will
interact directly with the DataStore because large file imports may
exhaust memory.

Note: This will also update the object metadata for this file.

=cut

sub
file_import()
{
    my ($self, $path) = @_;

    my $id = $self->id();

    if (! $id) {
        &eprint("This object has no ID!\n");
        return();
    }

    if ($path) {
        if ($path =~ /^([a-zA-Z0-9_\-\.\/]+)$/) {
            if (-f $path) {
                my $db = Warewulf::DataStore->new();
                my $binstore = $db->binstore($id);
                my $format;
                my $import_size = 0;
                my $buffer;
                my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($path);

                if (open(FILE, $path)) {
                    while(my $length = sysread(FILE, $buffer, $db->chunk_size())) {
                        if ($import_size eq 0) {
                            if ($buffer =~ /^#!\/bin\/sh/) {
                                $format = "shell";
                            } elsif ($buffer =~ /^#!\/bin\/bash/) {
                                $format = "bash";
                            } elsif ($buffer =~ /^#!\/[a-zA-Z0-9\/_\.]+\/perl/) {
                                $format = "perl";
                            } elsif ($buffer =~ /^#!\/[a-zA-Z0-9\/_\.]+\/python/) {
                                $format = "python";
                            } else {
                                $format = "data";
                            }
                        }
                        &dprint("Chunked $length bytes of $path\n");
                        $binstore->put_chunk($buffer);
                        $import_size += $length;
                    }
                    close FILE;

                    if ($import_size) {
                        if (! defined($self->get("uid"))) {
                            $self->uid($uid);
                        }
                        if (! defined($self->get("gid"))) {
                            $self->gid($gid);
                        }
                        if (! defined($self->get("path"))) {
                            $self->path($path);
                        }
                        if (! defined($self->get("mode"))) {
                            $self->mode(sprintf("%04o", $mode & 0777));
                        }
                        $self->size($import_size);
                        $self->checksum(digest_file_hex_md5($path));
                        $self->format($format);
                        $db->persist($self);
                    } else {
                        &eprint("Could not import file!\n");
                    }
                } else {
                    &eprint("Could not open file: $!\n");
                }
            } else {
                &eprint("File not found: $path\n");
            }
        } else {
            &eprint("Invalid characters in file name: $path\n");
        }
    }
}



=item file_export($file)

Export the data from a file object to a location on the file system.

=cut

sub
file_export()
{
    my ($self, $file) = @_;

    if ($file) {
        my $db = Warewulf::DataStore->new();
        if (! -f $file) {
            my $dirname = dirname($file);

            if (! -d $dirname) {
                mkpath($dirname);
            }
        }

        my $binstore = $db->binstore($self->id());
        if (open(FILE, "> $file")) {
            while(my $buffer = $binstore->get_chunk()) {
                print FILE $buffer;
            }
            close FILE;
        } else {
            &eprint("Could not open file for writing: $!\n");
        }
    }
}




=back

=head1 SEE ALSO

Warewulf::Object

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
