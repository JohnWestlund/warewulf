

package Warewulf::DBQuery;

use Warewulf::Logger;
use DBI;


=head1 NAME

Warewulf::DBQuery - Database query object interface

=head1 ABOUT

The Warewulf::DBQuery interface provides an abstract interface to the DB object

=head1 SYNOPSIS

    use Warewulf::DBQuery;

=item new(namespace)

Create the object. By default the namespace is that of the caller, but this
can be overridden if requested.

=cut
sub
new($$)
{
    my $proto               = shift;
    my $class               = ref($proto) || $proto;
    my $caller              = shift ||# ($caller, undef, undef) = caller(0);
    my $self;

    %{$self} = ();

    $self->{"NAMESPACE"} = $caller;

    bless($self, $class);

    return $self;
}


sub
get_namespace($)
{
    my $self = shift;

    return $self->{"NAMESPACE"};
}

=item add_match(entry to match, operator, constraint)

Add a matching constraint to the query. Allowed operators are:

    =, REGEXP, >, <, >=, <=

=cut
sub
add_match($$$$)
{
    my $self = shift;
    my $entry = shift;
    my $operator = shift;
    my $constraint = shift;

    push(@{$self->{"MATCHES"}}, [ $entry, $operator, $constraint ]);

}

sub
get_matches($)
{
    my $self = shift;

    return @{$self->{"MATCHES"}};
}

=item add_sort(field, ASC/DESC)

How should the results be sorted?

=cut
sub
add_sort($$$)
{
    my $self = shift;
    my $field = shift;
    my $order = shift;

    push(@{$self->{"SORT"}}, [ $field, $order ]);

}

sub
get_sorts()
{
    my $self = shift;

    return @{$self->{"SORT"}};
}


=item add_return(column name, present)

How should the data be presented? By default it will just return the string
corresponding to the entry requested, but you can also do a COUNT of the
entries found, or return the MAX entry.

=cut
sub
add_return($$$)
{
    my $self = shift;
    my $column = shift;
    my $present = shift;

    push(@{$self->{"RETURN"}}, [ $column, $present]);

}


sub
get_returns()
{
    my $self = shift;

    return @{$self->{"RETURN"}};
}

=item add_limit(start, count)

How many rows should be returned? The first argument is the first row to
display starting at zero, and the second argument is a count from the first.

=cut
sub
add_limit($$$)
{
    my $self = shift;
    my $start = shift;
    my $end = shift;

    push(@{$self->{"LIMIT"}}, [ $start, $end]);

}


sub
get_limits()
{
    my $self = shift;

    return @{$self->{"LIMIT"}};
}




1;
