(* ofuzz - ocaml fuzzing platform *)

(** ofuzz main

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
open Scheduling
open Optmanager
open Fuzzlib
open Triage
open Logger
open Fuzzinterface

let init_dirs knobs working_dir =
  if knobs.gen_all_tcs then cleanup_dir (get_tc_dir working_dir)
  else ();
  if knobs.gen_crash_tcs then cleanup_dir (get_crash_dir working_dir)
  else ()

let fuzzing_env knobs confs st =
  vlogf verbose "Fuzzing state initialized\n";
  let () = init_dirs knobs st.working_dir in
  let () = init_triage_script st.working_dir in
  st

let reproducing_env knobs confs rseed st =
  vlogf verbose "Reproducing %Ld\n" rseed;
  cleanup_dir (get_tc_dir st.working_dir);
  st

let init_env knobs confs =
  let cwd = init_fuzzing_env knobs.output_dir knobs.gui in
  let stats = Array.init (List.length confs) (fun _ -> null_stat ()) in
  let wnd = init_interface knobs in
  let st = init_fuzzing_state knobs confs stats cwd wnd in
  match knobs.reproduce_seed with
  | None -> fuzzing_env knobs confs st
  | Some (rseed, _) -> reproducing_env knobs confs rseed st

let destroy_env st confs exitcode =
  vlogf verbose "Finalizing the fuzzing state\n";
  if use_db st.knobs then Dbinsert.push_result st confs else ();
  if st.knobs.gui then disable_x_redirection () else ();
  destroy_fuzzing_state st;
  exitcode

(******************************************************************************)
(******************************************************************************)
(******************************************************************************)

let fuzz_main st confs testgen_alg scheduling =
  match testgen_alg with
  | RandomWithReplacement -> RandomFuzzer.launch st confs scheduling
  | SurfaceMutational -> SurfaceMutFuzzer.launch st confs scheduling
  | BallMutational -> BallMutFuzzer.launch st confs scheduling
  | ZzufMutational -> ZzufFuzzer.launch st confs scheduling
  | _ -> failwith "implement"

let reproduce_main st confs testgen_alg rseed confid =
  let conf = List.nth confs confid in
  match testgen_alg with
  | RandomWithReplacement -> RandomFuzzer.reproduce conf rseed st
  | SurfaceMutational -> SurfaceMutFuzzer.reproduce conf rseed st
  | BallMutational -> BallMutFuzzer.reproduce conf rseed st
  | ZzufMutational -> ZzufFuzzer.reproduce conf rseed st
  | _ -> failwith "implement"

let real_main st confs testgen_alg scheduling =
  match st.knobs.reproduce_seed with
  | None -> fuzz_main st confs testgen_alg scheduling
  | Some (rseed, confid) -> reproduce_main st confs testgen_alg rseed confid

let _ =
  let knobs, testgen_alg, scheduling, confs = opt_init () in
  let st = init_env knobs confs in
  vlogf verbose "Environment initialization done\n";
  try begin
    let st = real_main st confs testgen_alg scheduling in
    destroy_env st confs 0
  end with e -> begin
    let e = Printexc.to_string e in
    Printf.eprintf "%s\n" e;
    Printexc.print_backtrace stderr;
    logf "%s\n" e;
    destroy_env st confs 1
  end

