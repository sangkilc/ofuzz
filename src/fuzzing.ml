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
open Testgen
open Testeval
open Optmanager
open Logger
open Fuzzinterface
open Curses
open Misc

type fuzzing_state =
  {
    rseed         : int64;
    working_dir   : string;
    knobs         : knobs;
    stats         : fuzzstat array;
    initial_time  : float;
    wnd           : window;
  }

type timeout = float

let dbconnect knobs =
  let open Mysql in
  try
    let dbd =
      connect ~options:[]
        {
          dbhost=knobs.db_host;
          dbname=Some knobs.db_name;
          dbport=Some knobs.db_port;
          dbpwd=Some knobs.db_password;
          dbuser=Some knobs.db_user;
          dbsocket=None;
        }
    in
    Some dbd
  with Error e ->
    if use_db knobs then
      (Printf.eprintf "MySQL failure: %s\n" e; exit 1)
    else
      None

let init_fuzzing_state knobs confs stats cwd wnd =
  let () = init_logger (get_logfile cwd) knobs.verbosity in
  let () = init_testgen confs in
  let rseed = fst knobs.seed_range in
  let dbhandle = dbconnect knobs in
  let () =
    match dbhandle with
    | None -> ()
    | Some dbhandle -> Mysql.disconnect dbhandle
  in
  {
    rseed = rseed;
    working_dir = cwd;
    knobs = knobs;
    stats = stats;
    initial_time = 0.0;
    wnd = wnd;
  }

let destroy_fuzzing_state st =
  destroy_interface ();
  fin_logger ()

(** interrupt *)
exception Interrupt

let interrupt_handler _ =
  vlogf verbose "Interrupted by the user!\n"; flush ();
  raise Interrupt

(** fuzzing function type *)
type fuzzing_fn = timeout -> fuzzconf -> fuzzing_state -> fuzzing_state

module type FuzzingAlg =
sig

  val update_time_stat : int -> fuzzstat array -> float -> unit
  val fuzz : fuzzing_fn
  val reproduce : fuzzconf -> rseed -> fuzzing_state -> fuzzing_state

end

module Fuzzing =
  functor (TG: TestGen) ->
  functor (TE: TestEval) ->
struct

  let file_gen ((myfile, _):input) gendir =
    let digest = Digest.file myfile in
    let newfile = Digest.to_hex digest in
    logf "Generating a file %s into testcase dir\n" newfile;
    Fastlib.copy myfile (Filename.concat gendir newfile)

  let check_testcase tc st =
    if st.knobs.gen_all_tcs then
      file_gen tc (get_tc_dir st.working_dir)
    else ()

  let timediff time_begin =
    let cur_time = Unix.time () in
    cur_time -. time_begin, cur_time

  let update_runs_stat id stats =
    stats.(id) <- {stats.(id) with num_runs=stats.(id).num_runs+1}

  let update_time_stat id stats time_diff =
    stats.(id) <- {stats.(id) with time_spent=stats.(id).time_spent+.time_diff}

  let update_crash_stat id stats =
    stats.(id) <- {stats.(id) with num_crashes=stats.(id).num_crashes+1}

  let update_start_time id stats time =
    stats.(id) <- {stats.(id) with start_time=time}

  let update_finish_time id stats time =
    stats.(id) <- {stats.(id) with finish_time=time}

  let update_unique_stat id stats hash =
    if Hashtbl.mem stats.(id).unique_set hash.hashval then ()
    else Hashtbl.add stats.(id).unique_set hash.hashval hash

  let update_time id state fin_time time_diff =
    update_finish_time id state.stats fin_time;
    update_time_stat id state.stats time_diff;
    state

  let update_state id state tc result =
    match result with
    | Normal
    | TimedOut ->
        update_runs_stat id state.stats;
        {state with rseed=Int64.succ state.rseed}
    | Crashed hash ->
      begin
        update_runs_stat id state.stats;
        update_crash_stat id state.stats;
        if state.knobs.triage_on_the_fly then
          update_unique_stat id state.stats hash
        else ();
        if state.knobs.gen_crash_tcs then
          file_gen tc (get_crash_dir state.working_dir)
        else ();
        {state with rseed=Int64.succ state.rseed}
      end

  let fuzz timeout conf state =
    let rs, re = conf.mratio in
    vlogf verbose "Start fuzz-conf-%d for %f seconds (ratio: %f-%f)\n"
      (conf.confid) timeout rs re; flush ();
    let () = Sys.set_signal Sys.sigint (Sys.Signal_handle interrupt_handler) in
    let triage_verbose = state.knobs.verbosity > normal in
    let time_begin = Unix.time () in
    let id = conf.confid in
    let () = update_start_time id state.stats time_begin in
    let rec fuzz_loop state lastupdate =
      let testcase = TG.generate conf state.knobs state.rseed in
      let () = check_testcase testcase state in
      let result = TE.evaluate conf state.knobs triage_verbose testcase in
      let state = update_state id state testcase result in
      let time_diff, fin_time = timediff time_begin in
      let lastupdate =
        if fin_time -. lastupdate < update_interval then lastupdate
        else (update_status state.stats.(id) conf state.wnd; fin_time)
      in
      if time_diff >= timeout then update_time id state fin_time time_diff
      else fuzz_loop state lastupdate
    in
    let state =
      try fuzz_loop state time_begin
      with Interrupt ->
        let time_diff, fin_time = timediff time_begin in
        update_time id state fin_time time_diff
    in
    let () = Sys.set_signal Sys.sigint Sys.Signal_default in
    state

  let reproduce conf rseed state =
    let tc = TG.generate conf state.knobs rseed in
    file_gen tc (get_tc_dir state.working_dir);
    state

end

module RandomFuzzing = Fuzzing (RandomTestGen)(CrashEvalBySafeStack)
module SurfaceMutFuzzing = Fuzzing (SurfaceMutGen)(CrashEvalBySafeStack)
module BallMutFuzzing = Fuzzing (BallMutGen)(CrashEvalBySafeStack)
module ZzufFuzzing = Fuzzing (ZzufTestGen)(CrashEvalBySafeStack)

