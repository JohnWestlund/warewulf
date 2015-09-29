package Warewulf::Module::REST;

BEGIN {

    our ($VERSION);
    $VERSION = "0.00_01a";

    use Dancer qw(:syntax);
    use Warewulf::Module::REST::Node;
    use Warewulf::Module::REST::Vnfs;
    use Warewulf::Module::REST::Bootstrap;
    use Warewulf::Module::REST::File;
    use Warewulf::Module::REST::Provision;
}

prefix undef;

true;
