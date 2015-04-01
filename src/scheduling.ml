(* ofuzz - ocaml fuzzing platform *)

(** fuzz scheduling

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
open Fuzzing
open Optmanager
open Logger
open Misc

let print_statistic confid stat =
  logf "Statistics for (%3d) [#runs=%d; #crashes=%d; #unique=%d; #secs=%f] \
        ran from %s to %s\n"
    confid
    stat.num_runs
    stat.num_crashes
    (Hashtbl.length stat.unique_set)
    stat.time_spent
    (time_string stat.start_time)
    (time_string stat.finish_time)

let print_statistics state confs =
  Array.iteri (fun idx stat -> print_statistic idx stat) state.stats

module type SchedulingAlg =
sig
  val schedule : fuzzing_fn
              -> (unit -> bool)
              -> fuzzconf list
              -> fuzzing_state
              -> fuzzing_state
end

module RoundRobin : SchedulingAlg = Rr
module UniformTime : SchedulingAlg = Uniformtime
module WeightedRoundRobin : SchedulingAlg = Weightedrr

module Scheduler =
  functor (F: FuzzingAlg) ->
struct

  let launch st confs scheduling =
    let time_begin = Unix.time () in
    let st = {st with initial_time=time_begin} in
    let stopper =
      let timeout = float_of_int st.knobs.timeout in
      begin fun () ->
        let time_now = Unix.time () in
        (time_now -. time_begin) >= timeout
      end
    in
    let st =
      match scheduling with
      | RoundRobin ->
          RoundRobin.schedule F.fuzz stopper confs st
      | WeightedRoundRobin ->
          WeightedRoundRobin.schedule F.fuzz stopper confs st
      | UniformTime ->
          UniformTime.schedule F.fuzz stopper confs st
    in
    print_statistics st confs;
    st

  let reproduce = F.reproduce

end

(******************************************************************************)
(* Fuzzers                                                                    *)
(******************************************************************************)

module RandomFuzzer = Scheduler (RandomFuzzing)
module SurfaceMutFuzzer = Scheduler (SurfaceMutFuzzing)
module BallMutFuzzer = Scheduler (BallMutFuzzing)
module ZzufFuzzer = Scheduler (ZzufFuzzing)

