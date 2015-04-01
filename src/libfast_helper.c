/// ofuzz - ocaml fuzzing platform
/// @brief: fast native functions for ofuzz
/// @file: libfast_helper.c
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

#if defined(__APPLE__) || defined(__FreeBSD__)
#include <copyfile.h>
#else
#include <sys/sendfile.h>
#endif
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <sys/wait.h>
#include <errno.h>
#include <sys/mman.h>

// internal data structure for mmaped file
typedef struct {
  void* ptr;
  int size;
  int fd;
} filemap_t;

/// copy a file using a sendfile system call
/// @return: the number of successfully copied bytes
int copy( const char* file_from, const char* file_to )
{
    struct stat st;
    int ret = 0;
    int fd_from = open( file_from, O_RDONLY );
    int fd_to = open( file_to, O_CREAT | O_TRUNC | O_WRONLY, 0666 );

    if ( fd_from < 0 || fd_to < 0 ) goto error;

    if ( fstat( fd_from, &st ) < 0 ) goto error;

#if defined(__APPLE__) || defined(__FreeBSD__)
    ret = fcopyfile( fd_from, fd_to, NULL, COPYFILE_ALL ) < 0 ? 0 : 1;
#else
    ret = sendfile( fd_to, fd_from, NULL, st.st_size ) > 0 ? 1 : 0;
#endif

error:
    // printf( "copy %s -> %s: %d\n", file_from, file_to, ret );
    close( fd_from );
    close( fd_to );

    return ret;
}

static pid_t pid = 0;

static void alarm_callback( int sig )
{
    if ( pid )
        kill( pid, SIGKILL );
}

/// wait for a child process until a timeout
int waitchild( int timeout )
{
    int childstatus = 0;

    signal( SIGALRM, alarm_callback );
    alarm( timeout );

    while ( waitpid( pid, &childstatus, 0 ) < 0 && EINTR == errno ) {}

    alarm( 0 );

    if ( WIFEXITED( childstatus ) ) return 0;

    if ( WIFSIGNALED( childstatus ) ) {
        if ( WTERMSIG( childstatus ) == SIGSEGV ) return SIGSEGV;
        else if ( WTERMSIG( childstatus ) == SIGFPE ) return SIGFPE;
        else if ( WTERMSIG( childstatus ) == SIGILL ) return SIGILL;
        else return 0;
    } else {
        return 0;
    }
}

/// exec a child process with vfork
int exec( char** cmds, int len, int timeout, int allow_output, int* pid_ret )
{
    int ret = 0;
    int i = 0;
    char ** args = (char**) malloc( sizeof(char*) * (len + 1) );
    int devnull = 0;

    if ( !args ) {
        fprintf( stderr, "cannot allocate memory\n" ); exit( -1 );
    }

    for ( i = 0; i < len; i++ ) {
        args[i] = cmds[i];
        // printf( "CMD[%d]: %s\n", i, args[i] );
    }
    args[i] = 0;

    devnull = open( "/dev/null", O_RDWR );
    if ( devnull < 0 ) {
        perror( "devnull open" );
        exit( -1 );
    }

    pid = vfork();
    if ( pid == 0 ) {
        if ( !allow_output ) {
            dup2( devnull, STDOUT_FILENO );
            dup2( devnull, STDERR_FILENO );
        }
        execv( args[0], args );
        exit( -1 );
    } else if ( pid > 0 ) {
        ret = waitchild( timeout );
    } else {
        perror( "vfork" );
        exit( -1 );
    }

    close( devnull );

    free( args );
    *pid_ret = pid;
    return ret;
}

void* _map_file( const char* myfile, int filesize, int flag )
{
    int fd;
    filemap_t* map;

    fd = open( myfile, flag, 0666 );
    if ( fd < 0 ) {
        perror( "mapping error: open" );
        exit( -1 );
    }

    map = (filemap_t*) malloc( sizeof(filemap_t) );
    if ( !map ) {
        perror( "mapping error: malloc" );
        exit( -1 );
    }

    map->size = filesize;
    map->ptr = mmap( NULL, map->size, PROT_WRITE|PROT_READ, MAP_SHARED, fd, 0 );
    map->fd = fd;
    if ( (map->ptr) == (void*) -1 ) {
        perror( "mapping error: mmap" );
        exit( -1 );
    }
    // printf( "mapping: %p, %p\n", map, map->ptr );

    return map;
}

/// mmap existing file
void* map_file( const char* myfile, int filesize )
{
    return _map_file( myfile, filesize, O_RDWR );
}

/// unmap
void unmap_file( void* m )
{
    filemap_t* map = (filemap_t*) m;
    // printf( "unmapping: %p\n", m );
    munmap( map->ptr, map->size );
    close( map->fd );
    free( map );
}

/// modifying a byte in a mmapped file
void mod_file( void* m, int pos, char value )
{
    filemap_t* map = (filemap_t*) m;
    char* ptr = (char*) map->ptr;
    // printf( "mod_file %d\n", pos );
    ptr[pos] ^= value;
}

int get_mapping_size( int realsize )
{
    int page = getpagesize();
    return realsize + (realsize % page);
}

/// get the memory aligned file size that can be used for mmap
/// as well as the actual file size from a given file
int get_size_tuple( const char* path, int* realsize )
{
    struct stat st;
    int fd = open( path, O_RDONLY );

    if ( fd < 0 ) {
        perror( "get_size_tuple: open" );
        exit( -1 );
    }

    if ( fstat( fd, &st ) < 0 ) {
        perror( "get_size_tuple: fstat" );
        exit( -1 );
    }

    *realsize = st.st_size;

    close( fd );

    return get_mapping_size( *realsize );
}

