#########################################################
# This file created by Tim Copeland at
# Criterion Digital Copyright (c)
# with the hopes others will find it usefull
# and to help improve the project in general
#########################################################

package Warewulf::CrossArch;

use File::Path;
use File::Basename;
use File::Copy;

use Warewulf::Logger;

=item archsearch($path)

search given path for crossarch and return file name without ext
else return undef

=cut

sub
archsearch
{
    my ($path) = @_ ;
    my $filename = undef ;

    opendir (DIR, $path) or die $! ;
    while (my $file = readdir(DIR)) {
        if ( $file =~ m/^.*\.crossarch$/ ) {
            ($filename = $file) =~ s/\.crossarch$// ;
            last ;
        }
    }
    closedir(DIR) ;
    return $filename ;
}

1;
