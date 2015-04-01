(* minimizer - delta debugging on a crash, seed pair *)

(** minimizer

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
open Misc
open Fuzzlib
open Triage
open Filemapper

type knobs =
  {
    seed_path     : string;
    crasher_path  : string;
    cmds          : string list;
    seed_pos      : int;
    working_dir   : string;
    gui           : bool;
    exec_timeout  : int; (* timeout in seconds *)
  }

let opt_seed_path = StdOpt.str_option ~default:"" ~metavar:"<FILE>" ()
let get_seed_path () = Opt.get opt_seed_path

let opt_crasher_path = StdOpt.str_option ~default:"" ~metavar:"<FILE>" ()
let get_crasher_path () = Opt.get opt_crasher_path

let opt_seed_pos = StdOpt.int_option ~default:0 ~metavar:"<POS>" ()
let get_seed_pos () = Opt.get opt_seed_pos

let defaultwd = "min-output"
let opt_working_dir = StdOpt.str_option ~default:defaultwd ~metavar:"<DIR>" ()
let get_working_dir () = Opt.get opt_working_dir

let opt_gui = StdOpt.store_true ()
let get_gui () = Opt.get opt_gui

let opt_exec_timeout = StdOpt.int_option ~default:5 ~metavar:"<SEC>" ()
let get_exec_timeout () = Opt.get opt_exec_timeout

let opt_debugflag = StdOpt.store_true ()
let get_debugflag () = Opt.get opt_debugflag

let usage = "%prog <options> -s [seed] -c [crash] -f [pos] -- [cmd]"

let not_null argname = function
  | "" -> error_exit (Printf.sprintf "%s should be given." argname)
  | arg -> arg

let opt_init () =
  let myformatter =
    Formatter.indented_formatter ~max_help_position:50 ~width:100
                                 ~short_first:false ()
  in
  let p = OptParser.make ~usage:usage ~formatter:myformatter () in
  let () = OptParser.add p
             ~help:"specify the seed path"
             ~short_name:'s' ~long_name:"seed"
             opt_seed_path
  in
  let () = OptParser.add p
             ~help:"specify the crash path"
             ~short_name:'c' ~long_name:"crash"
             opt_crasher_path
  in
  let () = OptParser.add p
             ~help:"specify the seed argument position"
             ~short_name:'p' ~long_name:"pos"
             opt_seed_pos
  in
  let () = OptParser.add p
             ~help:"specify the working dir (default: min-output)"
             ~long_name:"working-dir"
             opt_working_dir
  in
  let () = OptParser.add p
             ~help:"enable GUI fuzzing"
             ~long_name:"gui"
             opt_gui
  in
  let () = OptParser.add p
             ~help:"execution timeout per exec call (default: 5 sec)"
             ~long_name:"exec-timeout"
             opt_exec_timeout
  in
  let () = OptParser.add p
             ~help:"debugging mode"
             ~long_name:"debug"
             opt_debugflag
  in
  let cmds = OptParser.parse_argv p in
  if List.length cmds > 0 then ()
  else (OptParser.usage p (); error_exit "Invalid args.");
  Printexc.record_backtrace (get_debugflag ());
  {
    seed_path = get_seed_path () |> not_null "seed file" |> to_abs;
    crasher_path = get_crasher_path () |> not_null "crashing file" |> to_abs;
    cmds = to_abs_cmds cmds;
    seed_pos = get_seed_pos ();
    working_dir = get_working_dir ();
    gui = get_gui ();
    exec_timeout = get_exec_timeout ();
  }

let sanitize_knobs knobs =
  if List.length knobs.cmds < (knobs.seed_pos + 1) then
    error_exit "The seed position is wrong."
  else if not (Sys.file_exists knobs.seed_path) then
    error_exit "The seed file not found. Use absolute path."
  else if not (Sys.file_exists knobs.crasher_path) then
    error_exit "The crasher file not found. Use absolute path."
  else if not (List.hd knobs.cmds |> check_program_availability) then
    error_exit "The executable is not available. Use absolute path."
  else
    ()

(******************************************************************************)
(* Message pipe                                                               *)
(******************************************************************************)

let outfd = ref None

let status_out knobs posset =
  let open Yojson.Safe in
  match !outfd with
  | None -> ()
  | Some fd ->
    begin
      let lst =
        IntSet.fold (fun pos lst -> (`Int pos)::lst) posset [] |> List.rev
      in
      let json =
        `Assoc [
                 ("filename", `String knobs.seed_path);
                 ("numbits", `Int (IntSet.cardinal posset));
                 ("bits", `List lst);
               ]
      in
      let msg = to_string json in
      try ignore (Unix.write fd msg 0 (String.length msg))
      with Unix.Unix_error (Unix.EPIPE, _, _) -> outfd := None
    end

let init_msg_pipe fd = outfd := Some fd

let shutdown_msg_pipe () =
  match !outfd with
  | None -> ()
  | Some fd -> try Unix.shutdown fd Unix.SHUTDOWN_ALL with _ -> ()

(******************************************************************************)
(******************************************************************************)
(******************************************************************************)

let one_run cwd cmds exec_timeout =
  let code, pid = execute (Array.of_list cmds) exec_timeout false in
  match is_crashing code with
  | Some _reason -> Some pid
  | None -> None

let rec distinct_bytes acc idx f1 f2 =
  if idx < 0 then acc
  else begin
    let c1 = get_char f1 idx in
    let c2 = get_char f2 idx in
    if c1 = c2 then distinct_bytes acc (idx-1) f1 f2
    else distinct_bytes (idx::acc) (idx-1) f1 f2
  end

let distinct_bits bytes f1 f2 =
  let rec get_distinct_bits byteidx c1 c2 bitpos acc =
    if bitpos >= 8 then acc
    else
      let b1 = ((int_of_char c1) lsr bitpos) land 0x01 in
      let b2 = ((int_of_char c2) lsr bitpos) land 0x01 in
      if b1 <> b2 then
        let acc = IntSet.add ((byteidx lsl 3) + bitpos) acc in
        get_distinct_bits byteidx c1 c2 (bitpos+1) acc
      else
        get_distinct_bits byteidx c1 c2 (bitpos+1) acc
  in
  IntSet.fold (fun byteidx acc ->
    Printf.printf "byte: %d\n" byteidx; flush stdout;
    let c1 = get_char f1 byteidx in
    let c2 = get_char f2 byteidx in
    assert (c1 <> c2);
    get_distinct_bits byteidx c1 c2 0 acc
  ) bytes IntSet.empty

let rec get_discard_probs acc idx n =
  if idx >= n then acc
  else get_discard_probs ((float idx /. float n) :: acc) (idx+1) n

(* randomly select [n] from a uniform distribution, and get a subset of the
   probabilities *)
let get_random_probs r m n maxn =
  let set = Comblib.floyds_sampling r (n-m) maxn in
  Hashtbl.fold (fun idx _ acc ->
    let idx = idx - 1 + m in
    (float idx /. float n) :: acc
  ) set []

let get_array_from_set set =
  let cnt = ref 0 in
  let arr = Array.make (IntSet.cardinal set) 0 in
  IntSet.iter (fun i -> arr.(!cnt) <- i; cnt := succ !cnt) set;
  arr

let get_disc_amount s p =
  let s = int_of_float ((float_of_int s) *. p) in
  if s < 1 then 1 else s

let bit_revert r seed crasher pos_array num_revert =
  let n = Array.length pos_array in
  let set = Comblib.floyds_sampling r n num_revert in
  Hashtbl.fold (fun idx _ acc ->
    let idx = idx - 1 in
    let bitidx = pos_array.(idx) in
    let byteidx = bitidx lsr 3 in
    let bitoffset = bitidx - (byteidx lsl 3) in
    let orig = get_char crasher byteidx |> int_of_char in
    let orig = orig lxor (0x1 lsl bitoffset) |> char_of_int in
    let () = set_char crasher byteidx orig in
    IntSet.add bitidx acc
  ) set IntSet.empty

let byte_revert r seed crasher pos_array num_revert =
  let n = Array.length pos_array in
  let set = Comblib.floyds_sampling r n num_revert in
  Hashtbl.fold (fun idx _ acc ->
    let idx = idx - 1 in
    let idx = pos_array.(idx) in
    let orig = get_char seed idx in
    let () = set_char crasher idx orig in
    IntSet.add idx acc
  ) set IntSet.empty

let minimize r revert cwd backup posset knobs seed hash filearg mindir =
  let confidence = 0.999 in
  let n = IntSet.cardinal posset in
  let rec loop minfound m posset =
    if minfound then
      posset
    else begin
      let maxn = 1000 in (* if the Hamming distance is too large, we just
                            consider small fraction of the probabilities *)
      let potential_probs =
        if n > maxn then get_random_probs r m n maxn
        else get_discard_probs [] m n
      in
      Printf.printf "Got (%d) potential probs. m = (%d)\n"
        (List.length potential_probs) m; flush stdout;
      let _, disc_chance =
        List.fold_left (fun (maxe,maxp) p ->
          let psucc = Prob.get_probability_of_success p m n in
          let expectation = psucc *. (float n) *. p in
          if expectation > maxe then expectation, p else maxe, maxp
        ) (0.0,0.0) potential_probs
      in
      Printf.printf "Computed new probability.\n"; flush stdout;
      let allowed_misses =
        (log (1.0 -. confidence)) /. (log (1.0 -. disc_chance))
        |> ceil |> int_of_float
      in
      Printf.printf "Chance: %f, Allowed misses: %d\n"
        disc_chance allowed_misses; flush stdout;
      let posset, foundnew =
        try_to_minimize disc_chance allowed_misses posset hash
      in
      let minfound = IntSet.cardinal posset <= m in
      loop minfound (if foundnew then m else m+1) posset
    end
  and try_to_minimize p loopcnt posset orighash =
    if loopcnt <= 0 then posset, false
    else begin
      let pos_array = get_array_from_set posset in
      let () = Fastlib.copy backup filearg in
      let newcrasher, _crashersize, crasherfd = map_writable filearg in
      let num_revert = get_disc_amount (Array.length pos_array) p in
      let () =
        Printf.printf "Loop(%d): disc_chance(%f), try to revert %d out of %d\n"
          loopcnt p num_revert (Array.length pos_array)
      in
      let () = flush stdout in
      let revertset = revert r seed newcrasher pos_array num_revert in
      Unix.close crasherfd;
      Gc.full_major ();
      Fastlib.copy filearg (Filename.concat mindir filearg);
      match one_run cwd knobs.cmds knobs.exec_timeout with
      | Some pid ->
          let hash = safe_stack_hash knobs.cmds pid knobs.exec_timeout false in
          if hash <> orighash then
            try_to_minimize p (loopcnt-1) posset orighash
          else
            found_smaller posset revertset
      | None ->
          try_to_minimize p (loopcnt-1) posset orighash
    end
  and found_smaller posset revertset =
    Fastlib.copy (Filename.concat mindir filearg) backup;
    let newset = IntSet.diff posset revertset in
    status_out knobs newset;
    newset, true
  in
  status_out knobs posset;
  if n = 1 then posset (* we don't need to do further minimization *)
  else loop false 1 posset

let min_start cwd knobs hash mindir filearg =
  let r = Random.get_state () in (* just use a default one *)
  let backupf = "crash.backup" in
  let seed, seedsize = map_file knobs.seed_path in
  let crasher, crashersize = map_file knobs.crasher_path in
  assert (seedsize = crashersize);
  let byte_positions = distinct_bytes [] (seedsize-1) seed crasher in
  let posset =
    List.fold_left (fun acc pos ->
      IntSet.add pos acc
    ) IntSet.empty byte_positions
  in
  Printf.printf "Seed size: (%d) bytes, Initial distance: (%d) bytes.\n\
                 Starting byte minimization.\n"
    seedsize (IntSet.cardinal posset); flush stdout;
  let () = Fastlib.copy knobs.crasher_path backupf in
  let byte_diff =
    minimize r byte_revert cwd backupf posset knobs seed hash filearg mindir
  in
  Fastlib.copy backupf filearg;
  let crasher, crashersize = map_file filearg in
  let totalbits = seedsize * 8 in
  let bit_diff = distinct_bits byte_diff seed crasher in
  Printf.printf "After the minimization, the distance became (%d) byte(s).\n\
                 Seed size: (%d) bit(s), Bit distance: (%d) bit(s).\n\
                 Starting bit minimization.\n"
    (IntSet.cardinal byte_diff) totalbits (IntSet.cardinal bit_diff);
  let bit_diff =
    minimize r bit_revert cwd backupf bit_diff knobs seed hash filearg mindir
  in
  Printf.printf "After the minimization, the distance became (%d) bit(s).\n"
    (IntSet.cardinal bit_diff);
  let copyto = Filename.concat mindir (Filename.basename knobs.seed_path) in
  let () = Fastlib.copy filearg copyto in
  Printf.eprintf "%s,%d,%d\n"
    (knobs.seed_path) (IntSet.cardinal byte_diff) (IntSet.cardinal bit_diff)


let rec listen_to_client sock =
  let client, _sockaddr = Unix.accept sock in
  init_msg_pipe client;
  listen_to_client sock

let init_domain_socket name =
  rm_if_exists name;
  let sock = Unix.socket Unix.PF_UNIX Unix.SOCK_STREAM 0 in
  Unix.bind sock (Unix.ADDR_UNIX name);
  Unix.listen sock 1;
  Sys.set_signal Sys.sigpipe Sys.Signal_ignore;
  Thread.create listen_to_client sock

let start_minimize knobs =
  let cwd = init_fuzzing_env knobs.working_dir knobs.gui in
  let () = init_triage_script cwd in
  let mindir = Filename.concat cwd "minfiles" in
  let () = cleanup_dir mindir in
  let _thr = init_domain_socket "/tmp/minimizer.sock" in
  let () = sanitize_knobs knobs in
  let cmds = knobs.cmds in
  let seedpath = knobs.seed_path in
  let crasherpath = knobs.crasher_path in
  let timeout = knobs.exec_timeout in
  let filearg = List.nth knobs.cmds knobs.seed_pos in
  assert (filearg <> crasherpath);
  Fastlib.copy crasherpath filearg;
  match one_run cwd cmds timeout with
  | Some pid ->
      let hash = safe_stack_hash cmds pid timeout false in
      min_start cwd knobs hash mindir filearg
  | None ->
      Printf.eprintf "%s,unreproducible\n" seedpath

let _ =
  let knobs = opt_init () in
  try start_minimize knobs; shutdown_msg_pipe (); 0
  with e ->
    Printf.eprintf "Fatal Error: %s\n" (Printexc.to_string e);
    Printexc.print_backtrace stderr; flush stderr;
    exit 1

