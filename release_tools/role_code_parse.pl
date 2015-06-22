#!/usr/bin/env perl

# Script for finding codes used in role name mapping, so if they change in cfengine we only need to change 1 file.


sub print_help
{
   print
"This script returns the code used for a specific role in the cfengine_role_codes.txt file

usage: $0 [OPTIONS] 

    -r, --role     =[provider|subscriber]  Find current term for the requested role
";
exit
}

use Getopt::Long;

$result = GetOptions (
  "role|r:s"          => \$in_role  # the colon instead of the equal sign means this can have 0 input values 
  , "help|?"            => \&print_help
);

if ($in_role eq "")
    {
      print_help;
    }
my $role_code = `grep "^$in_role:" cfengine_role_terms.txt | cut -d':' -f2`;
chomp $role_code;

if ($role_code eq "")
    {
      $role_code=$in_role;
    }
print STDOUT "$role_code";
exit;
