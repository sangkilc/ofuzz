(* ofuzz - ocaml fuzzing platform *)

(** option manager

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

open BatOptParse
open Fuzztypes

(** knobs that ofuzz utilizes while fuzzing *)
type knobs =
  {
    (* global *)
    verbosity          : int;
    output_dir         : string;
    timeout            : int;
    gui                : bool;
    full_debugging     : bool; (* show even program outputs for debugging *)
    (* db *)
    db_host            : string option;
    db_port            : int;
    db_user            : string;
    db_password        : string;
    db_name            : string;
    db_expid           : int;

    (* test-gen *)
    testgen_alg        : testgen_alg;
    seed_range         : seed_range;
    reproduce_seed     : (rseed * int) option;

    (* test-eval *)
    gen_all_tcs        : bool; (* generate all test cases (for debugging) *)
    gen_crash_tcs      : bool;
    triage_on_the_fly  : bool;
    exec_timeout       : int; (* execution timeout *)

    (* scheduling *)
    scheduling         : schedule;
    round_timeout      : int; (* timeout for a round (in round robin) *)
  }

(******************************************************************************)
(* Some Constants                                                             *)
(******************************************************************************)
let tcdir = "testcases"
let crashdir = "crashes"
let ofuzzlog = "ofuzz.log"

(******************************************************************************)
(* Useful Functions                                                           *)
(******************************************************************************)
let use_db knobs = knobs.db_host <> None
let get_tc_dir cwd = Filename.concat cwd tcdir
let get_crash_dir cwd = Filename.concat cwd crashdir
let get_logfile cwd = Filename.concat cwd ofuzzlog

(******************************************************************************)
(* Coerce Functions                                                           *)
(******************************************************************************)

let optional_value opt =
  try Some (Opt.get opt)
  with Opt.No_value -> None

let string_to_tc str =
  match String.lowercase str with
  | "zzuf" -> ZzufMutational
  | "random" | "rand" | "r" -> RandomWithReplacement
  | "randomwithoutreplacement" | "rwr" -> RandomWithoutReplacement
  | "ball" | "b" -> BallMutational
  | "surface" | "sur" | _ -> SurfaceMutational

let string_to_sch str =
  match String.lowercase str with
  | "round-robin" | "roundrobin" | "round" | "rr" -> RoundRobin
  | "weighted-rr" | "weightedrr" | "wrr" -> WeightedRoundRobin
  | "uniform-time" | "uniformtime" | "unitime" | _ -> UniformTime

let string_to_seed = Int64.of_string

let string_to_seed_range str =
  let regexp = Str.regexp_string ":" in
  match Str.split regexp str with
  | sbegin::send::[] -> string_to_seed sbegin, string_to_seed send
  | _ -> raise (Opt.Option_error ("seed-range", "invalid seed range format"))

let string_to_verbo str =
  match String.lowercase str with
  | "quiet" | "q" -> Logger.quiet
  | "verbose" | "v" -> Logger.verbose
  | "normal" | "n" | _ -> Logger.normal

let string_to_repropair str =
  let comma = Str.regexp_string "," in
  match Str.split comma str with
  | rseed::confid::[] -> string_to_seed rseed, int_of_string confid
  | _ ->
      raise (Opt.Option_error ("reproduce", "invalid format for reproduce"))

(******************************************************************************)
(* Defining Options                                                           *)
(******************************************************************************)

(* global *)
let opt_verbosity =
  StdOpt.any_option
    ~default:(Some Logger.normal) ~metavar:"<VERBOSITY>" string_to_verbo
let get_verbosity () = Opt.get opt_verbosity

let opt_output_dir =
  StdOpt.str_option ~default:"ofuzz-output" ~metavar:"<DIRNAME>" ()
let get_output_dir () = Opt.get opt_output_dir

let opt_timeout = StdOpt.int_option ~default:3600 ~metavar:"<SEC>" ()
let get_timeout () = Opt.get opt_timeout

let opt_gui = StdOpt.store_true ()
let get_gui () = Opt.get opt_gui

let opt_debugflag = StdOpt.store_true ()
let get_debugflag () = Opt.get opt_debugflag

(* test-gen *)
let opt_testgen_alg =
  StdOpt.any_option
    ~default:(Some SurfaceMutational) ~metavar:"<ALG>" string_to_tc
let get_testgen_alg () = Opt.get opt_testgen_alg

let opt_seedrange =
  StdOpt.any_option
    ~default:(Some default_seed_range)
    ~metavar:"<BEGIN:END>" string_to_seed_range
let get_seedrange () = Opt.get opt_seedrange

let opt_reproduce =
  StdOpt.any_option
    ~metavar:"<RSEED,CONF_ID>"
    string_to_repropair
let get_reproduce () = optional_value opt_reproduce

(* test-eval *)
let opt_genall_tcs = StdOpt.store_true ()
let get_genall_tcs () = Opt.get opt_genall_tcs

let opt_gencrash_tcs = StdOpt.store_true ()
let get_gencrash_tcs () = Opt.get opt_gencrash_tcs

let opt_triage = StdOpt.store_true ()
let get_triage () = Opt.get opt_triage

let opt_exec_timeout = StdOpt.int_option ~default:5 ~metavar:"<SEC>" ()
let get_exec_timeout () = Opt.get opt_exec_timeout

(* scheduling *)
let opt_scheduling =
  StdOpt.any_option
    ~default:(Some UniformTime) ~metavar:"<ALG>" string_to_sch
let get_scheduling () = Opt.get opt_scheduling

let opt_round_timeout = StdOpt.int_option ~default:5 ~metavar:"<SEC>" ()
let get_round_timeout () = Opt.get opt_round_timeout

(* database *)
let opt_dbhost = StdOpt.str_option ~default:"" ~metavar:"<HOSTNAME>" ()
let get_dbhost () =
  let dbhost = Opt.get opt_dbhost in
  if dbhost = "" then None else Some dbhost

let opt_dbport = StdOpt.int_option ~default:3306 ~metavar:"<PORT>" ()
let get_dbport () = Opt.get opt_dbport

let opt_dbuser = StdOpt.str_option ~default:"fuzzer" ~metavar:"<USERNAME>" ()
let get_dbuser () = Opt.get opt_dbuser

let opt_dbpassword = StdOpt.str_option ~default:"" ~metavar:"<PASSWORD>" ()
let get_dbpassword () =
  let get_password_from_cmdline () =
    let () = output_string stdout "password for the db: " in
    let () = flush stdout in
    let open Unix in
    let attr = tcgetattr stdin in
    let () = attr.c_echo <- false in
    let () = tcsetattr stdin TCSAFLUSH attr in
    let password = input_line Pervasives.stdin in
    let () = attr.c_echo <- true in
    let () = tcsetattr stdin TCSAFLUSH attr in
    let () = print_endline "" in
    password
  in
  let password = Opt.get opt_dbpassword in
  if password = "" && get_dbhost () <> None then get_password_from_cmdline ()
  else password

let opt_dbname = StdOpt.str_option ~default:"fuzzing" ~metavar:"<DBNAME>" ()
let get_dbname () = Opt.get opt_dbname

let opt_dbexpid = StdOpt.int_option ~default:0 ~metavar:"<EID>" ()
let get_dbexpid () = Opt.get opt_dbexpid

(******************************************************************************)
(******************************************************************************)

let read_conf_files p files =
  if List.length files = 0 then begin
    OptParser.usage p ();
    Misc.error_exit "\nError: a conf file is required to start ofuzz"
  end else
    try begin
      List.fold_left (fun acc file ->
        let lst = Conf.parse file in
        List.rev_append lst acc
      ) [] files
    end with
      | Conf.WrongFormat reason ->
          Misc.error_exit ("\nError (WrongFormat): "^reason)
      | Not_found ->
          Misc.error_exit ("\nError: file not found")
      | e ->
          (* Printf.eprintf "what? %s" (Printexc.to_string e); *)
          Misc.error_exit "\nError: cannot read conf file(s)"

let usage = "%prog [options] <ofuzz config file(s)>"

let opt_init () =
  let myformatter =
    Formatter.indented_formatter ~max_help_position:50 ~width:100
                                 ~short_first:false ()
  in
  let p = OptParser.make ~usage:usage ~formatter:myformatter () in
  let grp_testgen = OptParser.add_group p "Options related to Test-Gen" in
  let grp_testeval = OptParser.add_group p "Options related to Test-Eval" in
  let grp_scheduling = OptParser.add_group p "Scheduling Options" in
  let grp_global = OptParser.add_group p "Global Options" in
  let grp_db = OptParser.add_group p "Database Options" in
  (* global options *)
  let () = OptParser.add p
             ~long_name:"version"
             (StdOpt.version_option Ofuzzversion.string)
  in
  let () = OptParser.add p
             ~group:grp_global
             ~help:"debugging mode"
             ~long_name:"debug"
             opt_debugflag
  in
  let () = OptParser.add p
             ~group:grp_global
             ~help:"verbosity (quiet|normal|verbose) (default: normal)"
             ~short_name:'v' ~long_name:"verbosity"
             opt_verbosity
  in
  let () = OptParser.add p
             ~group:grp_global
             ~help:"specify a timeout"
             ~short_name:'t' ~long_name:"timeout"
             opt_timeout
  in
  let () = OptParser.add p
             ~group:grp_global
             ~help:"enable GUI fuzzing"
             ~long_name:"gui"
             opt_gui
  in
  let () = OptParser.add p
             ~group:grp_global
             ~help:"specify the name of the output directory"
             ~short_name:'o' ~long_name:"output"
             opt_output_dir
  in
  (* test-gen options *)
  let () = OptParser.add p
             ~group:grp_testgen
             ~help:"test-gen algorithms (rand|rwr|mut|sur|zzuf)"
             ~long_name:"test-gen-alg"
             opt_testgen_alg
  in
  let () = OptParser.add p
             ~group:grp_testgen
             ~help:"specify a seed range tuple"
             ~short_name:'s' ~long_name:"seed-range"
             opt_seedrange
  in
  let () = OptParser.add p
             ~group:grp_testgen
             ~help:"reproduce a test case"
             ~long_name:"reproduce"
             opt_reproduce
  in
  (* test-eval *)
  let () = OptParser.add p
             ~group:grp_testeval
             ~help:"specify whether to generate all the test cases \
                    in the output directoy (only for debugging)"
             ~long_name:"gen-all-tcs"
             opt_genall_tcs
  in
  let () = OptParser.add p
             ~group:grp_testeval
             ~help:"specify whether to generate crash test cases \
                    in the output directoy"
             ~long_name:"gen-crash-tcs"
             opt_gencrash_tcs
  in
  let () = OptParser.add p
             ~group:grp_testeval
             ~help:"perform bug triaging on the fly"
             ~long_name:"triage"
             opt_triage
  in
  let () = OptParser.add p
             ~group:grp_testeval
             ~help:"execution timeout per exec call (default: 5 sec)"
             ~long_name:"exec-timeout"
             opt_exec_timeout
  in
  (* scheduling *)
  let () = OptParser.add p
             ~group:grp_scheduling
             ~help:"specify a scheduling algorithm"
             ~long_name:"scheduling"
             opt_scheduling
  in
  let () = OptParser.add p
             ~group:grp_scheduling
             ~help:"specify a round timeout (round-robin)"
             ~long_name:"round-timeout"
             opt_round_timeout
  in
  (* database *)
  let () = OptParser.add p
             ~group:grp_db
             ~help:"specify db host name"
             ~long_name:"host"
             opt_dbhost
  in
  let () = OptParser.add p
             ~group:grp_db
             ~help:"specify db port"
             ~long_name:"port"
             opt_dbport
  in
  let () = OptParser.add p
             ~group:grp_db
             ~help:"specify db username"
             ~long_name:"user"
             opt_dbuser
  in
  let () = OptParser.add p
             ~group:grp_db
             ~help:"specify db password"
             ~long_name:"password"
             opt_dbpassword
  in
  let () = OptParser.add p
             ~group:grp_db
             ~help:"specify db name"
             ~long_name:"dbname"
             opt_dbname
  in
  let () = OptParser.add p
             ~group:grp_db
             ~help:"specify experiment id"
             ~long_name:"exp-id"
             opt_dbexpid
  in
  (* parsing *)
  let rest = OptParser.parse_argv p in
  (* reading conf file(s) *)
  let conflst = read_conf_files p rest in
  (* enable backtrace *)
  let () = if get_debugflag () then Printexc.record_backtrace true else () in
  {
    verbosity = get_verbosity ();
    output_dir = get_output_dir ();
    timeout = get_timeout ();
    gui = get_gui ();
    full_debugging = get_debugflag () && (get_verbosity () = Logger.verbose);

    db_host = get_dbhost ();
    db_port = get_dbport ();
    db_user = get_dbuser ();
    db_password = get_dbpassword ();
    db_name = get_dbname ();
    db_expid = get_dbexpid ();

    testgen_alg = get_testgen_alg ();
    seed_range = get_seedrange ();
    reproduce_seed = get_reproduce ();

    gen_all_tcs = get_genall_tcs ();
    gen_crash_tcs = get_gencrash_tcs ();
    triage_on_the_fly = get_triage ();
    exec_timeout = get_exec_timeout ();

    scheduling = get_scheduling ();
    round_timeout = get_round_timeout ();
  },
  get_testgen_alg (),
  get_scheduling (),
  conflst

