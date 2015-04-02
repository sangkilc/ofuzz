#!/bin/bash
ver=$(ocamlopt -version)
major=$(echo $ver | cut -f1 -d'.')
minor=$(echo $ver | cut -f2 -d'.')
ver=${major}.${minor}

echo $ver \
| awk '{if($1 >= 4.02){print ""} else{print "module Bytes = String"}}'
