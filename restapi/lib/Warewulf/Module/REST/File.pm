package Warewulf::Module::REST::File;


use Dancer;
use Dancer::Plugin::REST;
use Warewulf::Module::EasyFuncs::File qw(get_all_files get_file_contents set_file_contents get_files set_file_properties del_file create_new_file);

#set serializer => 'mutable';
set serializer => 'JSON';
prefix '/file';

# REST routes
get '/' => \&all_file_data;
get '/:fileid' => \&get_file_data;
post '/' => \&upload_file;
del '/:fileid' => \&delete_file;
put '/:fileid' => \&change_file_data;
get '/:fileid/contents' => \&gfile_contents;
put '/:fileid/contents' => \&sfile_contents;

sub all_file_data {
    eval {
        my %files = get_all_files();
        status(200); # 200 OK
        return { "files" =>\%files };
    } or do {
        status(500); # 500 Internal Server Error
        return { "error" => $@ };
    }
}

sub get_file_data {
    eval {
        my $fid = params->{fileid};
        my @fids = ($fid);
        my %file;
        if ( $fid =~ m/^([0-9]+)$/ ) {
            %file = get_files('_id',\@fids);
        } elsif ( $fid =~ m/^(\w+)/ ) {
            %file = get_files('name',\@fids);
        } else {
            status(500);
            return { "error" => "Unrecognized \$fid value: $fid" };
        }
        status(200); # 200 OK
        return { "file" => \%file };
    } or do {
        status(500); # 500 Internal Server Error
        return { "error" => $@ };
    }
}

sub upload_file {
    eval {
        my $upload = upload('file');
        my $name = $upload->basename();
        my $path = $upload->tempname();
        open(FILE, $path);
        my $contents = do { local $/; <FILE> };
        my $uid = params->{uid};
        my $gid = params->{gid};
        my $mode = params->{mode};
        #my $path = params->{path}; ## ??? 
        my %fstatus = create_new_file($name,$uid,$gid,$mode,$path,$contents);
        status(200); # 200 OK
        return { "file" => \%fstatus };
    } or do {
        status(500); # 500 Internal Server Error
        return { "error" => $@ };
    };
}

sub delete_file {
    eval {
        my $id = params->{fileid};
        del_file($id);
        status(200); # 200 OK
        return { "status" => "OK" };
    } or do {
        status(500); # 500 Internal Server Error
        return { "error" => $@ };
    };
}

sub change_file_data {
    eval {
        my $json = params->{json};
        my $href = from_json($json);
        my %fdata = %{$href};
        my %result = set_file_properties(\%fdata);
        status(200); # 200 OK
        return { "file" => \%result };
    } or do {
        status(500); # 500 Internal Server Error
        return { "error" => $@ };
    };
}

sub gfile_contents {
    my $id = params->{fileid};
    my $contents = get_file_contents($id) || undef;
    my %fobj;
    $fobj{$id}{'lookup'} = $id;

    if ($contents) {
        $fobj{$id}{'contents'} = $contents;
        status(200);
        #return { "contents" => "$result" };
        return { "file" => \%fobj };
        #return { $result };
    } else {
        status(500);
        return { "error" => "Could not get file contents for file id $id" };
    }
}

sub sfile_contents {
    my $id = params->{fileid};
    my $contents = params->{contents};
    my $result = set_file_contents($id,$contents);
    if ($result==1) {
        status(202); # 202 Accepted
        return { "status" => "success" };
    } else {
        status(500);
        return { "error" => $result };
    }
}

