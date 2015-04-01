(* ofuzz - ocaml fuzzing platform *)

(** triage module

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

open Misc
open Fuzzlib
open Fuzztypes
open Optmanager
open Logger
open Triage_scripts

(** supported debugger types *)
type debugger =
  | GDB of string
  | LLDB of string
  | DebuggerNotAvailable

(** triage script path *)
let triagescript = ref ""
let triagecmd = ref ""
let triagedebugger = ref DebuggerNotAvailable
let triagecorefile = ref (fun (_:int) -> "core")

(** check usable debugger and return it *)
let usable_debugger () =
  if check_program_availability "gdb" then
    GDB (get_abspath_for_bin "gdb")
  else if check_program_availability "lldb" then
    LLDB (get_abspath_for_bin "lldb")
  else
    DebuggerNotAvailable

(** read one line from a file *)
let read_one_line file =
  let ch = open_in file in
  try
    let line = input_line ch in
    close_in ch;
    line
  with _ ->
    close_in ch;
    ""

let triage_txt = "triage.txt"

let return_core_file pid = Printf.sprintf "/cores/core.%d" pid

let clean_if_exists file =
  if Sys.file_exists file then Unix.unlink file else ()

let clean_up_triage_txt () = clean_if_exists triage_txt
let clean_up_core core = clean_if_exists core

module type TriageAlg =
sig

  val triage_from_core : string
                      -> string
                      -> string list
                      -> int
                      -> bool
                      -> crashhash

  val triage_from_debugger : string -> string list -> int -> bool -> crashhash

end

module SafeStackHash (T: TriageAlg) =
struct

  let compute_crash_hash dbg cmds pid timeout do_output =
    let core = !triagecorefile pid in
    if Sys.file_exists core then
      T.triage_from_core dbg core cmds timeout do_output
    else
      T.triage_from_debugger dbg cmds timeout do_output

end

(** triaging from GDB *)
module GdbTriage: TriageAlg =
struct

  let triage_from_core dbg core cmds timeout do_output =
    let prog = List.hd cmds in
    let gdb_command =
      dbg::"-x"::!triagescript
         ::"-x"::!triagecmd
         ::"-batch"::"-c"::core
         ::prog::[]
      |> Array.of_list
    in
    let _ = execute gdb_command timeout do_output in
    let stackhash = read_one_line triage_txt in
    stackhash

  let triage_from_debugger _dbg _cmds _timeout _do_output = failwith "implement"

end

(** lldb stackhash triaging *)
module LldbTriage : TriageAlg =
struct

  let triage_from_core dbg core cmds timeout do_output =
    let prog = List.hd cmds in
    let lldb_command =
      dbg::prog::"-c"::core
         ::"-l"::"python"
         ::"-s"::!triagecmd::[]
      |> Array.of_list
    in
    let _ = execute lldb_command timeout do_output in
    let () = clean_up_core core in
    let stackhash = read_one_line triage_txt in
    stackhash

  let triage_from_debugger dbg cmds timeout do_output =
    let lldbcmd =
      dbg::"-l"::"python"::"-s"::!triagecmd::"--"::cmds
      |> Array.of_list
    in
    let () = clean_up_triage_txt () in
    let _ = execute lldbcmd timeout do_output in
    let stackhash = read_one_line triage_txt in
    if stackhash = "" then "Unreproducible"
    else stackhash

end

let write_to_file path str =
  let ch = open_out path in
  output_string ch str;
  close_out ch

let generate_triage_scripts pypath gdbpath py gdb =
  write_to_file pypath (BatBase64.str_decode py);
  write_to_file gdbpath (BatBase64.str_decode gdb)

let check_script_version pypath gdbpath py gdb =
  let enc_py =
    BatBase64.str_encode (BatFile.with_file_in pypath BatIO.read_all)
  in
  let enc_gdb =
    BatBase64.str_encode (BatFile.with_file_in gdbpath BatIO.read_all)
  in
  if (enc_py = py && enc_gdb = gdb) then ()
  else generate_triage_scripts pypath gdbpath py gdb

let init_triage_script cwd =
  let pypath = Filename.concat cwd "triage.py" in
  let gdbpath = Filename.concat cwd "triage.gdb" in
  triagescript := pypath;
  triagecmd := gdbpath;
  triagedebugger := usable_debugger ();
  if Envmanager.os = "Darwin" then triagecorefile := return_core_file else ();
  let py, gdb =
    (* debugger check *)
    match !triagedebugger with
    | GDB _ -> triage_py, triage_gdb
    | LLDB _ -> triage_llpy, triage_lldb
    | DebuggerNotAvailable -> failwith "there's no usable debugger"
  in
  if Sys.file_exists pypath && Sys.file_exists gdbpath then
    check_script_version pypath gdbpath py gdb
  else
    generate_triage_scripts pypath gdbpath py gdb

(******************************************************************************)
(* Safe Stack Hash                                                            *)
(******************************************************************************)

module GdbSafeStackHash = SafeStackHash(GdbTriage)
module LldbSafeStackHash = SafeStackHash(LldbTriage)

let safe_stack_hash cmds pid timeout do_output =
  match !triagedebugger with
  | GDB gdb ->
      GdbSafeStackHash.compute_crash_hash gdb cmds pid timeout do_output
  | LLDB lldb ->
      LldbSafeStackHash.compute_crash_hash lldb cmds pid timeout do_output
  | _ -> failwith "there's no usable debugger"

module SafeStack = struct

  let triage pid knobs verbose reason cmds (_, rseed) =
    let hash =
      if knobs.triage_on_the_fly then
        safe_stack_hash cmds pid knobs.exec_timeout verbose
      else ""
    in
    let md5 = Digest.string hash |> Digest.to_hex in
    logf "%10Ld %s [%s]\n" rseed reason hash;
    Crashed {hashval=md5; backtrace=hash}

end

