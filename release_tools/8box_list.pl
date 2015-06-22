#!/usr/bin/env perl

# Script for gleaning 8box cluster information from the clusterinfo_parse.pl script

sub print_help
{
   print
"This script generates a list from the entries matching the 8box_clusters.txt file, then outputs the list to STDOUT which you can sort/parse further in the calling script.

usage: $0 [OPTIONS] 

    -s, --servers_only  Output only distinct server names for standard 8Boxes clusters
    -c, --cluster       =?    Output clusters for only the cluster passed in. Default is all 8Box clusters returned.
    -r, --role          =[provider|subscriber|snapshot]  Output only clusters serving that role. Default is to include just provider and subscriber.

";
   exit
}

use Getopt::Long;
$result = GetOptions (
  "role|r=s"       => \$in_role      
  , "cluster|c=s"    => \$in_cluster
  , "servers_only|s" => \$in_servers_only
  , "help|?"         => \&print_help
);

my %servers;
my @wholelist;
my $file='8box_clusters.txt';

if ($in_cluster)
{
  push (@wholelist, $in_cluster);
} else
{
  open (FH, "< $file") or die "Can't open $file for read: $!";
  @wholelist = <FH>;
  close FH or die "Cannot close $file: $!"; 
}

if (! @wholelist)
{ print STDERR "\nERROR-> Cannot determine which clusters.\n\n"; }

my $inx_role=`role_code_parse.pl -r $in_role`;
foreach my $box ( @wholelist )
{
  chomp $box;
  my @return = `clusterinfo_parse.pl --active_only --cluster=$box --role=$inx_role`;
  # make sure script was found and returned *something*
  if (! @return)
  { print STDERR "\nERROR-> Cannot find clusterinfo_parse.pl script in PATH or nothing returned from it.\n\n"; }

  foreach my $return_line ( @return )
  {
    my ($machine, $cluster) = split(" ", $return_line);
    if ($in_servers_only)
    {
      $server_hash{$machine}=$machine;
    } else 
    {
      $database = `ssh -q $machine "PGCLUSTER=$cluster PGUSER=postgres psql template1 --tuples-only --no-align --command \'select datname from pg_database\' " | grep -vE 'postgres|template'`;   
      chomp $database;
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
