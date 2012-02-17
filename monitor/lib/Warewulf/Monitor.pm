# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#

package Warewulf::Monitor;

use Warewulf::Object;
use Warewulf::ObjectSet;
use Warewulf::Logger;
use JSON::XS;
use IO::Socket;


@ISA = ('Warewulf::Object');

=head1 NAME

Warewulf::Monitor - Warewulf Monitor module to provide abilies to communicate
                    with Warewulf monitor database.

=head1 ABOUT

Blah blah blah

=head1 SYNOPSIS

    use Warewulf::Monitor;

    my $monitor = Warewulf::Monitor->new();
    $monitor->set_query("NODENAME='ksong.lbl.gov'");
    my $ObjectSet = $monitor->query_data();

    foreach my $node_object ( $ObjectSet->get_list()) {
        printf("%-20s CPU: %s\n", $node_object->get("name"), $node_object->get("cpuutil"));
    }



=head1 METHODS

=over 12

=cut



=item new()

The new constructor will create the object that references configuration the
stores.

=cut

my $HEADERSIZE=4;
my $APPLICATION=2;

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

##
# initialize monitor object with defaut
# localhost at port 9000
##
sub init()
{
    my ($self, @args) = @_;
    $self->master('localhost',9000);

    return $self;
}

##
# Private method to send raw and complete 
# sql query to monitor master
# it returns a object set according the query
##
my $query = sub
{
    my ($self, $query) = @_;
    my $json = JSON::XS->new();
    my $ObjectSet = Warewulf::ObjectSet->new();
    my $data;
    my $sock;

    # Build Socket conditionally if ! exists
    if (! $self->get("socket")) {
	# Make socket connection
	my ($host,$port) = $self->master();
	my $socket = IO::Socket::INET->new(PeerAddr => $host,
					   PeerPort => $port,
					   Proto => 'tcp');
	unless ( $socket ) {
	    print "Could not connect to $host:$port!\n";
	}

	$self->set("socket", $socket);
	#regist connection type for this socket 
	register_conntype ($socket,$APPLICATION);
	my $register_data=recv_all($socket);
    }
    $sock=$self->get("socket");

    #send raw query as json packet
    send_query($sock,$query);
    my $data=recv_all($sock);

    #decode json packet and restore it in the object set data structure
    my %decoded_json = %{decode_json($data)};
    foreach my $node (keys %decoded_json) {
	my $tmpObject = Warewulf::Object->new();
	$tmpObject->set("name",$node);
	foreach my $entry (keys %{$decoded_json{$node}}) {
	    $tmpObject->set($entry, $decoded_json{"$node"}{"$entry"});
	    &dprint("Set entry for node: $node ($entry....)\n");
	}
	$ObjectSet->add($tmpObject);
    }
    if (! $self->persist_socket()) {
	# tear down socket
	print "socket distroyed.\n";
	close($sock);
    }
    return $ObjectSet;
};

##
# use persist_socket("1") to prevent socket being closed
# after each query
##
sub persist_socket()
{
    my ($self, $bool) = @_;

    if ($bool) {
	$self->set("persist_socket", "1");
    }

    return $self->get("persist_socket");
}

sub
    destroy_socket()
{
    my ($self) = @_;
    if ( ! $self->get("socket")) {
	print "socket is not defined for $self\n";

    }else{
	# destroy socket connection
	close($self->get("socket"));
    }
}
	
##
# set monitor master host and port
# if calling without arguement, it will return the current
# master host and port
##
sub master()
{
    my ($self, $remotehost, $port) = @_;

    if ($remotehost) {
	$self->set("remotehost", $remotehost);
    }
    if ($port) {
	$self->set("port", $port);
    }

    return ($self->get("remotehost"),$self->get("port"));
}

##
# set the where clause for a query for this object
##
sub set_query(){
    my ($self, $whereClause) = @_;
    $self->set("query","select * from wwstats where $whereClause");
}

##
# retrieving data from the "query" that is set via set_query()
# if "query" is not set, get all the data
##
sub query_data(){
    my ($self) = @_;
    if (!$self->get("query")){
	return $query->($self, "select * from wwstats");
    }else{
	return $query->($self, $self->get("query"));
    }
}

sub register_conntype {
    my ($socket, $type) = @_;
    my $json = JSON::XS->new();
    my $jsonStruc;
    $jsonStruc->{CONN_TYPE} = $type;
    my $json_text = $json->encode($jsonStruc);
    send_all($socket,$json_text);
}

sub send_query {
    my ($socket, $sql) = @_;
    my $sqlJson = JSON::XS->new();
    my $jsonStruc;
    $jsonStruc->{"sqlite_cmd"}=$sql;
    my $jsonQuery=$sqlJson->encode($jsonStruc);
    send_all($socket,$jsonQuery);
}

sub send_all {
    my ($socket, $payload) = @_;
    my $length=length($payload);
#as of now, $length is the only packet header
    $socket->send(pack('ia*', $length,$payload));
}

sub recv_all {
    my ($socket) = @_;
    my $header;
    my $rawdata;
    $socket->recv($header, $HEADERSIZE,MSG_WAITALL);
    my $pktsize=unpack('i',$header);
    $socket->recv($rawdata, $pktsize,MSG_WAITALL);
    my $data=unpack('a*',$rawdata);
    return $data;
}


sub
    update_node_entry()
{
    # will send post to monitor

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
