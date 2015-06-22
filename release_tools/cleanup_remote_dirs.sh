#!/bin/bash

# This will go to each unique server and remove and release tar files or release directories there in YOUR local directory.

for server in `perl cnuapp_list.pl --servers_only`
do
        echo "Removing the following release files from: $server.";
        ssh -q $server "ls -lad local/r201* | grep local; rm -rf ~/local/r201*";
        echo " ";
done;
