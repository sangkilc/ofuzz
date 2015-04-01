(* ofuzz - ocaml fuzzing platform *)

(** define fuzzing

    @author Sang Kil Cha <sangkil.cha\@gmail.com>
    @since  2014-03-19

 *)

(*
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
*)

open Fuzztypes
open Optmanager
open Mysql

type fuzzing_state =
  {
    rseed        : int64;
    working_dir  : string;
    knobs        : knobs;
    stats        : fuzzstat array;
    initial_time : float;
  }

type timeout = float

val init_fuzzing_state : knobs -> fuzzconf list -> string -> fuzzing_state

val destroy_fuzzing_state : fuzzing_state -> unit

val dbconnect : knobs -> Mysql.dbd option

(** Fuzzing function type *)
type fuzzing_fn = timeout -> fuzzconf -> fuzzing_state -> fuzzing_state

module type FuzzingAlg =
sig

  val update_time_stat : int -> fuzzstat array -> float -> unit
  val fuzz : fuzzing_fn
  val reproduce : fuzzconf -> rseed -> fuzzing_state -> fuzzing_state

end

module RandomFuzzing : FuzzingAlg
module SurfaceMutFuzzing : FuzzingAlg
module BallMutFuzzing : FuzzingAlg
module ZzufFuzzing : FuzzingAlg

