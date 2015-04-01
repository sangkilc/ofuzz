/// ofuzz - ocaml fuzzing platform
/// @brief: probability computation library for ofuzz
/// @file: libprob_helper.c
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
#include <gmp.h>
#include <mpfr.h>

float get_probability_of_success( float p, int m, int num )
{
    float ret = 0.;
    mpfr_t n, N, M, one, prob, t, nfact, NMfact, Nfact, nMfact;

    mpfr_init( N );
    mpfr_set_ui( N, num, MPFR_RNDD );

    mpfr_init( M );
    mpfr_set_ui( M, m, MPFR_RNDD );

    mpfr_init( one );
    mpfr_set_ui( one, 1, MPFR_RNDD );

    mpfr_init( n );
    mpfr_init( prob );
    mpfr_set_ui( n, 0, MPFR_RNDD );
    mpfr_set_flt( prob, p, MPFR_RNDD );
    mpfr_sub( prob, one, prob, MPFR_RNDD );
    mpfr_mul( n, prob, N, MPFR_RNDD );

    ///////////////////////////////////////////
    mpfr_init( t );
    mpfr_init( nfact );
    mpfr_init( NMfact );
    mpfr_init( nMfact );
    mpfr_init( Nfact );

    mpfr_add( t, n, one, MPFR_RNDD );
    mpfr_gamma( nfact, t, MPFR_RNDD );

    mpfr_sub( t, N, M, MPFR_RNDD );
    mpfr_add( t, t, one, MPFR_RNDD );
    mpfr_gamma( NMfact, t, MPFR_RNDD );

    mpfr_add( t, N, one, MPFR_RNDD );
    mpfr_gamma( Nfact, t, MPFR_RNDD );

    mpfr_sub( t, n, M, MPFR_RNDD );
    mpfr_add( t, t, one, MPFR_RNDD );
    mpfr_gamma( nMfact, t, MPFR_RNDD );

    ///////////////////////////////////////////

    mpfr_mul( t, nfact, NMfact, MPFR_RNDD );
    mpfr_div( t, t, Nfact, MPFR_RNDD );
    mpfr_div( t, t, nMfact, MPFR_RNDD );

    ret = mpfr_get_flt( t, MPFR_RNDD );

    mpfr_clear( n );
    mpfr_clear( N );
    mpfr_clear( M );
    mpfr_clear( one );
    mpfr_clear( prob );
    mpfr_clear( t );
    mpfr_clear( nfact );
    mpfr_clear( NMfact );
    mpfr_clear( Nfact );
    mpfr_clear( nMfact );

    return ret;
}

