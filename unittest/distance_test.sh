#!/bin/bash

###############################################################################
# OFuzz Unit Test                                                             #
#                                                                             #
# Copyright (c) 2014, Sang Kil Cha                                            #
# All rights reserved.                                                        #
# This software is free software; you can redistribute it and/or              #
# modify it under the terms of the GNU Library General Public                 #
# License version 2, with the special exception on linking                    #
# described in file LICENSE.                                                  #
#                                                                             #
# This software is distributed in the hope that it will be useful,            #
# but WITHOUT ANY WARRANTY; without even the implied warranty of              #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                        #
###############################################################################

OUTPUTDIR=ofuzz-output

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "Hamming distance test started."
rm -rf $OUTPUTDIR
echo -n "Fuzzing run ... "
../ofuzz --triage --timeout=20 --gen-crash-tcs ./test.conf
if [ "$?" -ne "0" ]; then
    echo -e "${RED}[failed]${NC}"
    exit 1
else
    echo -e "${GREEN}[succeeded]${NC}"
fi

echo -n "Output check ... "
if [ ! -d "$OUTPUTDIR" ]; then
    echo -e "${RED}[failed]${NC}"
    exit 1
else
    echo -e "${GREEN}[succeeded]${NC}"
fi

echo -n "Testcase check ... "
for file in $OUTPUTDIR/crashes/*
do
    diff=$(../utils/hamming $file testseed | awk -F, '{print $1}')
    if [ "$diff" -ne "2" ]; then
        echo -e "${RED}[failed]${NC}"
        echo -e "${RED}$file${NC} has $diff"
        exit 1
    fi
done
echo -e "${GREEN}[succeeded]${NC}"

