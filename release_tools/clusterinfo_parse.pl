#!/usr/bin/env perl

# Script for gleaning cluster information from the /etc/enki/clusterinfo.json file
# and output a space delimited list to STDOUT.

use JSON;   

sub print_help
{
   print
"This script generates a list of entries in the clusterinfo.json file.
It generates STDOUT which you can sort/parse further in the calling script in the format of:
'full server name' 'version'/'cluster'
However, passing the servers_only paramter only ouputs the full-server names.

usage: $0 [OPTIONS] 

    -a, --active_only       Output only active clusters. 
    -s, --servers_only      Output only distinct server names.
    -c, --cluster  =?       Output cluster names that contain this value. 
    -r, --role     =[provider|subscriber|snapshot|standalone|special]  Output only clusters serving that role. 
                              If no role specified, only provider and subscriber roles are output.
    -f, --fqdn              Output additionally the fqdn value
";
exit
}

use Getopt::Long;

$result = GetOptions (
  "active_only|a"       => \$in_active_only
  , "cluster|c=s"       => \$in_cluster
  , "role|r:s"          => \$in_role  # the colon instead of the equal sign means this can have 0 input values 
  , "servers_only|s"    => \$in_servers_only
  , "fqdn|f"    	=> \$in_fqdn
  , "help|?"            => \&print_help
);

my $provider_term = `role_code_parse.pl -r provider`;
my $subscriber_term = `role_code_parse.pl -r subscriber`;
my $inx_role = `role_code_parse.pl -r $in_role`;

my %servers;
my $clusterfile_json="/etc/enki/clusterinfo.json";
{
   local $/; #enable slurp
   open my $cfh, "<", "$clusterfile_json";
   $cluster_json = <$cfh>;
}

my %clusterfile = %{ decode_json($cluster_json) };

foreach my $key ( keys %clusterfile )
{
    my $info = $clusterfile{$key};
    my $full_server_name = "$info->{'machine'}.cashnetusa.com";
    $full_server_name =~ s/\.oak\.cashnetusa\.com$/.mgmt.oak.enova.com/;    #hack around not having domain name in the json file
    
    if ( 
        (($in_active_only and $$info{active} eq "yes") or (! $in_active_only))
        and 
        (($in_cluster ne "" and $$info{cluster} =~ $in_cluster) or $in_cluster eq "")
        and 
        (($in_role ne "" and $$info{role} eq $inx_role ) 
            or ($in_role eq "" 
                and ($$info{role} eq "$provider_term" or $$info{role} eq "$subscriber_term")))
    )
    {
   	if ($in_servers_only)
        {
         $server_hash{$full_server_name}=$full_server_name;
        } else 
        {
	  if ($in_fqdn) 
	   {
             my $format = "%s %s/%s %s %s\n";
             print STDOUT "$full_server_name $info->{'version'}/$info->{'cluster'} $info->{'fqdn'}\n";
           }
          else
           {
             my $format = "%s %s/%s %s\n";
             print STDOUT "$full_server_name $info->{'version'}/$info->{'cluster'}\n";
           } 
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
