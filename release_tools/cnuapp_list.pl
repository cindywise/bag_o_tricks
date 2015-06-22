#!/usr/bin/env perl

# Script for gleaning cnuapp cluster information from the clusterinfo_parse.pl script

sub print_help
{
   print
"This script generates a list from the CNUAPP entries, then outputs the list to STDOUT which you can sort/parse further in the calling script.

usage: $0 [OPTIONS] 

    -s, --servers_only  Output only distinct server names for standard CNUAPP clusters
    -p, --pnl           =?    Output clusters for only the P&L passed in. Default is all standard CNUAPP clusters returned (us, uk, jv, ca). 
    -r, --role          =[subscriber|provider|snapshot]  Output only clusters serving that role. Default is to include just provider and subscriber.

";
exit
}

use Getopt::Long;

$result = GetOptions (
  "role|r=s"   => \$in_role      
  , "pnl|p=s" => \$in_pnl
  , "servers_only|s" => \$in_servers_only
  , "help|?"          => \&print_help
);

my %servers;
my @standard_list = qw(ca jv uk us);

my @return = `clusterinfo_parse.pl --active_only --cluster=cnuapp --role=$in_role`;

# make sure script was found and returned *something*
if (! @return)
{ print STDERR "\nERROR-> Cannot find clusterinfo_parse.pl script in PATH or nothing returned from it.\n\n"; }

foreach my $return_line ( @return )
{
  my ($machine, $cluster) = split(" ", $return_line);

  $cluster =~ /^.*\/(.*?)\-.*$/; 
  my $pnl = $1;

  if (($in_pnl ne "" and $in_pnl eq $pnl) 
      or ($in_pnl eq ""   # handle requesting the 'standard' set of cnuapp clusters 
          and $pnl ~~ @standard_list))
     {
 	    if ($in_servers_only)
         {
          $server_hash{$machine}=$machine;
         } else 
         {
          my $database = "cnuapp_prod";
          if ($pnl ne "us")   # handle cnuapp U.S. database names differently
             {
              $database .= '_' . $pnl;
             }
          print STDOUT "$machine $cluster $database\n";
         }
     }
}

if ($in_servers_only)
   {
    foreach my $key  (sort keys (%server_hash)) 
       {
        print STDOUT "$server_hash{$key}\n";
       }
   }

exit;
