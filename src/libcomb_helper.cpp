/// ofuzz - ocaml fuzzing platform
/// @brief: combinatorial related native functions for ofuzz
/// @file: libcomb_helper.cpp
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

#include "libcomb.h"

#include <gmp.h>

#if defined(__APPLE__) || defined(__FreeBSD__)
#include <unordered_map>
#else
#include <tr1/unordered_map>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <stdint.h>

class neighbor_info_t
{
public:
    __mpz_struct* total;
    __mpz_struct* last;
#if defined(__APPLE__) || defined(__FreeBSD__)
    std::unordered_map< unsigned int, __mpf_struct* > ratiomap;
#else
    std::tr1::unordered_map< unsigned int, __mpf_struct* > ratiomap;
#endif

    neighbor_info_t( __mpz_struct* total, __mpz_struct* last ):
        total( total ),
        last( last )
    {
    }
};

#if defined(__APPLE__) || defined(__FreeBSD__)
typedef
std::unordered_map< uint64_t, neighbor_info_t* >
pair_cache_t;
#else
typedef
std::tr1::unordered_map< uint64_t, neighbor_info_t* >
pair_cache_t;
#endif

// memoize total neighbor size
pair_cache_t total_neighbor_cache;

uint64_t nk_pair( unsigned int n, unsigned int k )
{
    return ((uint64_t) n << 32) | (uint64_t) k;
}

__mpz_struct* new_mpz()
{
    __mpz_struct* z = (__mpz_struct*) malloc( sizeof( __mpz_struct ) );
    assert( z && "allocation failed" );
    mpz_init( z );
    return z;
}

__mpz_struct* copy_mpz( __mpz_struct* ptr )
{
    __mpz_struct* n = new_mpz();
    mpz_set( n, ptr );
    return n;
}

neighbor_info_t*
init_neighbors( unsigned int n, unsigned int k )
{
    pair_cache_t::const_iterator it =
      total_neighbor_cache.find( nk_pair( n, k ) );
    if ( it != total_neighbor_cache.end() ) {
        return it->second;
    }

    mpz_t z_acc;
    mpz_t z_comb;
    mpz_t z_prevcomb;

    mpz_init( z_acc );
    mpz_init( z_comb );
    mpz_init( z_prevcomb );

    mpz_set_ui( z_acc, 1 );
    mpz_set_ui( z_prevcomb, 1 );

    for ( unsigned int i = 1; i <= k; i ++ ) {
        mpz_mul_ui( z_comb, z_prevcomb, n-i+1 );
        mpz_div_ui( z_comb, z_comb, i );
        mpz_add( z_acc, z_acc, z_comb );
        mpz_set( z_prevcomb, z_comb );
    }

    __mpz_struct* z_n = copy_mpz( z_acc );
    __mpz_struct* z_prev = copy_mpz( z_prevcomb );
    neighbor_info_t* pinfo = new neighbor_info_t( z_n, z_prev );
    assert( pinfo && "allocation failed" );

    mpz_clear( z_acc );
    mpz_clear( z_comb );
    mpz_clear( z_prevcomb );

    total_neighbor_cache.insert( std::make_pair( nk_pair( n, k ), pinfo ) );

    return pinfo;
}

void get_next_partition( unsigned int n, unsigned int k, unsigned int pos,
                         __mpz_struct* z_last )
{
    for ( unsigned int i = k; i > pos; i -- ) {
        mpz_mul_ui( z_last, z_last, k );
        mpz_div_ui( z_last, z_last, n-k+1 );

        k -= 1;
    }
}

// int check_position( mpz_t z_r, unsigned int n, unsigned int k,
//                     neighbor_info_t pair )
// {
//     int pos = 0;
//     mpz_t last_pos;
//
//     mpz_init( last_pos );
//
//     mpz_sub( last_pos, pair.first, pair.second );
//
//     if ( mpz_cmp( z_r, last_pos ) >= 0 ) {
//         pos = k;
//     } else {
//         pos = get_next_pos( z_r, n, k, last_pos, pair.second );
//     }
//
//     mpz_clear( last_pos );
//     return pos;
// }

#ifdef __cplusplus
extern "C"
{
#endif

double get_partition_ratio( unsigned int n, unsigned int k, unsigned int pos )
{
    double ret = 0.0;
    mpz_t partition;
    mpf_t r, p, t;
    neighbor_info_t* pinfo = init_neighbors( n, k );

    mpz_init( partition );
    mpf_init( r );
    mpf_init( p );
    mpf_init( t );

    mpz_set( partition, pinfo->last );
    get_next_partition( n, k, pos, partition );

    mpf_set_z( p, partition );
    mpf_set_z( t, pinfo->total );
    mpf_div( r, p, t );
    ret = mpf_get_d( r );

    mpz_clear( partition );
    mpf_clear( r );
    mpf_clear( p );
    mpf_clear( t );
    return ret;
}

gmp_random_state init_gmp_random()
{
    __gmp_randstate_struct* rstate =
        (__gmp_randstate_struct*) malloc( sizeof(__gmp_randstate_struct) );
    assert( rstate && "allocation failed" );

    gmp_randinit_default( rstate );
    // gmp_randseed_ui( rstate, (int) seed );

    return (gmp_random_state) rstate;
}

void seed_gmp_random( gmp_random_state state, uint64_t seed )
{
    __gmp_randstate_struct* rstate = (__gmp_randstate_struct*) state;
    gmp_randseed_ui( rstate, (int) seed );
}

void clear_gmp_random( gmp_random_state state )
{
    __gmp_randstate_struct* rstate = (__gmp_randstate_struct*) state;
    gmp_randclear( rstate );
    free( rstate );
    state = NULL;
}

#ifdef __cplusplus
}
#endif

