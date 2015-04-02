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

echo "Hamming distance test started."
rm -rf $OUTPUTDIR
echo "Fuzzing run."
../ofuzz.native --triage --timeout=20 --gen-crash-tcs ./test.conf
echo -n "Testcase check ... "
for file in ofuzz-output/crashes/*
do
    diff=$(../utils/hamming $file testseed | awk -F, '{print $1}')
    if [ "$diff" -ne "2" ]; then
        echo "Test failure."
        exit 1
    fi
done
echo "passed."

