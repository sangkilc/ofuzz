/// ofuzz - ocaml fuzzing platform
/// @brief: fuzzing related native functions for ofuzz
/// @file: libfuzz_helper.cpp
/// @author: Sang Kil Cha <sangkilc@cmu.edu>
/// @date: 2014/03/19

/*
Copyright (c) 2014, Sang Kil Cha
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the <organization> nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL SANG KIL CHA BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 */

#include <stdio.h>
#include <limits.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/resource.h>
#include <boost/filesystem.hpp>

/// rm -rf path\*
void _remove_dir_contents( const char* path )
{
    if ( access( path, F_OK ) == -1 ) return;

    boost::filesystem::path path_to_remove( path );
    for ( boost::filesystem::directory_iterator end_dir_it, it( path_to_remove );
          it != end_dir_it;
          ++it )
    {
        remove_all( it->path() );
    }
}

#ifdef __cplusplus
extern "C"
{
#endif

/// ulimit -c unlimited
void set_coredump()
{
    struct rlimit limit = {RLIM_INFINITY, RLIM_INFINITY};
    if ( setrlimit( RLIMIT_CORE, &limit ) < 0 ) {
        perror( "setrlimit" );
        exit( -1 );
    }
}

void remove_dir_contents( const char* path )
{
    _remove_dir_contents( path );
}

#ifdef __cplusplus
}
#endif

