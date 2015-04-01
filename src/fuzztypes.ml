(* ofuzz - ocaml fuzzing platform *)

(** common types for fuzzing

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

(** test-gen algorithms *)
type testgen_alg =
  | RandomWithReplacement
  | RandomWithoutReplacement
  | SurfaceMutational
  | BallMutational
  | ZzufMutational

let alg_to_string = function
  | RandomWithReplacement -> "Random w/ Replacement"
  | RandomWithoutReplacement -> "Random w/o Replacement"
  | SurfaceMutational -> "Surface-based Mutational"
  | BallMutational -> "Ball-based Mutational"
  | ZzufMutational -> "Zzuf Mutational"

(** random seed *)
type rseed = int64

(** random seed range *)
type seed_range = rseed * rseed
let default_seed_range = (0L, Int64.max_int)

(** input (path to the modified file, random seed) *)
type input = string * rseed

(** crash hash *)
type crashhash = string

(** crash id type *)
type crash_id =
  {
    hashval   : crashhash;
    backtrace : string;
  }

(** fuzzing result *)
type fuzzresult =
  | Normal
  | TimedOut
  | Crashed of crash_id

(** fuzz configuration *)
type fuzzconf =
  {
    confid             : int;
    cmds               : string list;
    cmds_array         : string array;
    filearg_idx        : int;
    mratio             : float * float; (* range of mutation ratios *)
    seed_file          : string;
    part_file          : string;
    input_size         : int;
  }

(** per-configuration stat *)
type fuzzstat =
  {
    unique_set         : (string, crash_id) Hashtbl.t;
    num_crashes        : int;
    num_runs           : int;
    time_spent         : float;
    start_time         : float;
    finish_time        : float;
  }
let null_stat () =
  let set = Hashtbl.create 101 in
  {
    unique_set = set;
    num_crashes = 0;
    num_runs = 0;
    time_spent = 0.0;
    start_time = 0.0;
    finish_time = 0.0;
  }

(** scheduling algorithms *)
type schedule =
  | RoundRobin
  | WeightedRoundRobin
  | UniformTime (* give a uniform time (timeout option) for each conf *)

let schedule_to_string = function
  | RoundRobin -> "round-robin"
  | WeightedRoundRobin -> "weighted-rr"
  | UniformTime -> "uniform-time"

