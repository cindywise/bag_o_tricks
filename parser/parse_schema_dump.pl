#!/usr/bin/perl -w

# This script will take a cnudump-generated, or regular pg_dump, output of a database from STDIN and parse it into STDOUT. 

sub print_help
{
   print
"This script accepts a dump file as STDIN to parse it and prepend each line with the schema and object name for sorting needed for diffing.
It generates STDOUT which you can redirect to a file.
You run this script once per dump file (with the same options), then you can easily diff the two parsed output files to highlight differences.
Note that lines longer than 500 bytes are 'folded' into multiple lines for easier diffing.
Filtering in or out of specific objects is possible using grep on the output.


usage: cat [dump file] | $0 [OPTIONS] > [output file]

    -s, --schema	    include schema-related dump info with ownership
    -t, --table		    include table-related dump info (table definition) with ownership
    -p, --privilege  	include privilege/acl/permission-related dump info
    -i, --index 	    include index-related dump info
    -f, --fk		      include foreign key constraint-related dump info
    -c, --constraint  include constraint-related dump info for: primary keys, unique keys and checks
    -v, --view		    include view-related dump info with ownership
    -r, --rule		    include rule-related dump info
    -d, --default  	  include default column value-related dump info
    -g, --trigger	    include trigger-related dump info with ownership
    -q, --sequence	  include sequence-related dump info with ownership
    -x, --function 	  include function-related dump info with ownership
    -m, --comment	    include comment-related dump info
    -y, --type 		    include type-related dump info with ownership
    -n, --domain	    include domain-related dump info with ownership
    -e, --aggregate	  include aggregate-related dump info with ownership
    -o, --operator	  include operator-related dump info
    -z, --all  		    include all schema objects listed above, except seed data (assumed when no options are passed in)
    -a, --data  	    include seed data

";
exit
}

sub process_options () {
  use Getopt::Long qw(GetOptionsFromArray :config ignorecase pass_through bundling);

  @opts = @ARGV;
  my ($ret) = GetOptionsFromArray(
    \@opts
    , \%h
    , 'schema|s'  	  => \$_schema
    , 'table|t' 	    => \$_table
    , 'sequence|q'	  => \$_sequence
    , 'index|i'		    => \$_index
    , 'fk|f'		      => \$_fk
    , 'constraint|c'	=> \$_constraint
    , 'default|d'	    => \$_default
    , 'trigger|g'	    => \$_trigger
    , 'view|v'		    => \$_view
    , 'rule|r'		    => \$_rule
    , 'comment|m'	    => \$_comment
    , 'privilege|p'	  => \$_privilege
    , 'data|a'		    => \$_data
    , 'function|x'	  => \$_function
    , 'type|y'		    => \$_type
    , 'domaini|n'	    => \$_domain
    , 'aggregate|e'	  => \$_aggregate
    , 'operator|o'	  => \$_operator
    , 'all|z'         => \$_all
    , 'help|?' 		    => \&print_help
  );

  if (@ARGV == 0) {
	$_all = 1;
  }
  my $bla=$h{data};
}

process_options();

if ( -t STDIN )
 {
	print STDERR "\nABORTING. No input provided via STDIN.\n\n";
	&print_help;
 }

my $temp_file = '/tmp/temp_schema.dmp';
my $work_file = '/tmp/work_schema.dmp';

my $schema;
my $obj_type;
my $obj_name;
my $obj_seq='00000';
my $obj_line_num='0000000';
my @cells;
my @obj_parse;
my $obj_id;
my $obj_key;
my %bld_hash;
my $in_line;
my @out_hash;

#Copy original file
open (TEMPFL, "> $temp_file") or die "Unable to open TEMP output file ($temp_file)\n";
while ( <STDIN> )
 {
  print TEMPFL "$_";
 }


#Replace object identifiers' comments with something that differentiates the line
system("perl -pi -e 's/-- Name:(.\*\?); Type:(.\*\?); Schema:(.\*\?); Owner:(.\*\?)/;;objid;; Name:\$1;; Type:\$2;; Schema:\$3;; Owner:\$4/' $temp_file");
system("perl -pi -e 's/-- Data for Name:(.\*\?); Type:(.\*\?); Schema:(.\*\?); Owner:(.\*\?)/;;objid;; Name:\$1;; Type:\$2;; Schema:\$3;; Owner:\$4/' $temp_file");

#Remove all comment lines and set lines 
system("grep -viE '^--|^SET ' $temp_file > $work_file; mv $work_file $temp_file;"); 

#Parse long lines into multiple lines for easier comparison
system("cat $temp_file | fold -bw500 > $work_file"); 

open(INFILE,"< $work_file") or print "Unable to open input file\n";

while (<INFILE>) 
 {
  chomp;
  $in_line = $_;
  @cells=split ('\;\;',$_);

  if ($in_line)   # skip blank lines
    {
     if ($cells[1])
       { 
        if ($cells[1] eq "objid")
          { 
  	   # increment the object counter (in case different objects have the same name, they can be sorted separately
	   $obj_seq ++;
	   $obj_line_num='0000000';

           # load the object name
           @obj_parse=split ('\: ', $cells[2]);
           $obj_name=$obj_parse[1];
           $obj_name=~ s/^SCHEMA //;

	   # load the object type
           @obj_parse=split ('\: ', $cells[3]);
           $obj_type=$obj_parse[1];
           if ($obj_type eq "COMMENT")
           {
              $obj_name=~ s/^.*? //;   # object type (like TABLE, COLUMN, etc) is put in front of object name for comments in the dump, so this strips object type off
           }

           $obj_type =~ s/^SCHEMA/00SCHEMA/;
           $obj_type =~ s/^DEFAULT/15DEFAULT/;
           $obj_type =~ s/^SEQUENCE/20SEQUENCE/;
           $obj_type =~ s/^CONSTRAINT/25CONSTRAINT/;
           $obj_type =~ s/^FK CONSTRAINT/30FKCONSTRAINT/;
           $obj_type =~ s/^INDEX/35INDEX/;
           $obj_type =~ s/^TRIGGER/40TRIGGER/;
           $obj_type =~ s/^TABLE DATA/45DATA/;
           $obj_type =~ s/^TABLE/10TABLE/;
           $obj_type =~ s/^VIEW/50VIEW/;
           $obj_type =~ s/^RULE/55RULE/;
           $obj_type =~ s/^COMMENT/60COMMENT/;
           $obj_type =~ s/^ACL/65ACL/;
           $obj_type =~ s/^FUNCTION/70FUNCTION/;
           $obj_type =~ s/^TYPE/75TYPE/;
           $obj_type =~ s/^DOMAIN/80DOMAIN/;
           $obj_type =~ s/^AGGREGATE/85AGGREGATE/;
           $obj_type =~ s/^OPERATOR.*/90OPERATOR/;

	   # load the schema name
           @obj_parse=split ('\: ', $cells[4]);
           $schema=$obj_parse[1]. ".";
           if ($schema eq "\-.")
              { 
               $schema="";  
	             $obj_id = $obj_name .'. '. $obj_type .' '. $obj_seq;
              }
           else 
              {
	             $obj_id = $schema . $obj_name . $obj_type .' '. $obj_seq;
              }
          }
       }
        else
       { 
        if ($obj_id) 
           {
            $obj_line_num ++;        # increment the line number for correct sorting
            $obj_key = $obj_id .' '. $obj_line_num;        # object key is the whole object id with the line number

	    if ((($_all  
    		|| ($_schema 		  && $obj_type eq "00SCHEMA")
    		|| ($_table  		  && $obj_type eq "10TABLE")
    		|| ($_default  		&& $obj_type eq "15DEFAULT")
    		|| ($_sequence  	&& $obj_type eq "20SEQUENCE")
    		|| ($_constraint  && $obj_type eq "25CONSTRAINT")
    		|| ($_fk  		    && $obj_type eq "30FKCONSTRAINT")
    		|| ($_index  		  && $obj_type eq "35INDEX")
    		|| ($_trigger  		&& $obj_type eq "40TRIGGER")
    		|| ($_view  		  && $obj_type eq "50VIEW")
    		|| ($_rule  		  && $obj_type eq "55RULE")
    		|| ($_comment  		&& $obj_type eq "60COMMENT")
    		|| ($_privilege  	&& $obj_type eq "65ACL")
    		|| ($_function  	&& $obj_type eq "70FUNCTION")
    		|| ($_type  		  && $obj_type eq "75TYPE")
    		|| ($_domain  		&& $obj_type eq "80DOMAIN")
    		|| ($_aggregate  	&& $obj_type eq "85AGGREGATE")
    		|| ($_operator  	&& $obj_type eq "90OPERATOR")
		 ) && ($obj_type ne "45DATA"))
		|| ($_data  		&& $obj_type eq "45DATA"))
		{
           	 if ($bld_hash{$obj_key}) 
             	    { 
               		print STDERR "!! EXISTS ?? $bld_hash{$obj_key}\n";
             	    }
           	    $bld_hash{$obj_key} = $schema . $obj_name .': '. $in_line;   # save the object key and dump line into a hash
          	}
	   }
       }
    }
 } # end of while loop

close (INFILE);

print STDOUT "Options selected (sorted): \n";
print STDOUT "	--aggregate | -e\n"   if $_aggregate;
print STDOUT "	--all | -z\n"         if $_all;
print STDOUT "	--comment | -m\n"     if $_comment;
print STDOUT "	--constraint | -c\n"  if $_constraint;
print STDOUT "	--data | -a\n"        if $_data;
print STDOUT "	--default | -d\n"     if $_default;
print STDOUT "	--domain | -n\n"      if $_domain;
print STDOUT "	--fk | -f\n"          if $_fk;
print STDOUT "	--function | -x\n"    if $_function;
print STDOUT "	--index | -i\n"       if $_index;
print STDOUT "	--operator | -o\n"    if $_operator;
print STDOUT "	--privilege | -p\n"   if $_privilege;
print STDOUT "	--rule | -r\n"        if $_rule;
print STDOUT "	--schema | -s\n"      if $_schema;
print STDOUT "	--sequence | -q\n"    if $_sequence;
print STDOUT "	--table | -t\n"       if $_table;
print STDOUT "	--trigger | -g\n"     if $_trigger;
print STDOUT "	--type | -y\n"        if $_type;
print STDOUT "	--view | -v\n"        if $_view;
print STDOUT "----------------------------\n";

# sort the hash array by constructed object key, and print out
foreach my $key  (sort keys (%bld_hash)) 
       {
        print STDOUT "$bld_hash{$key}\n";
       }

system ("rm $work_file");
system ("rm $temp_file");

exit;


# vi: expandtab sw=2 ts=2
