(* ofuzz - ocaml fuzzing platform *)

(** miscellaneous

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

open Compatibility

exception Overflow

module AddrSet = Set.Make(Nativeint)
module AddrMap = Map.Make(Nativeint)
module StringSet = Set.Make(String)
module StringMap = Map.Make(String)
module IntMap = Map.Make(struct type t = int let compare = compare end)
module IntSet = Set.Make(struct type t = int let compare = compare end)

let readlines file =
  let chan = open_in file in
  let lines = ref [] in
  try
    while true do
      lines := input_line chan :: !lines
    done; []
  with End_of_file ->
    close_in chan;
    List.rev !lines

let error_exit msg =
  Printf.eprintf "%s\n" msg;
  exit 1

let (|>) a b = b a

let get_filesize path =
  let stat = Unix.stat path in
  stat.Unix.st_size

let dissect_path pathenv =
  let path = Sys.getenv pathenv in
  let colon = Str.regexp_string ":" in
  Str.split colon path

let check_program_availability prog =
  if Sys.file_exists prog then true
  else begin
    List.exists
      (fun path -> Sys.file_exists (Filename.concat path prog))
      (dissect_path "PATH")
  end

let get_abspath_for_bin prog =
  let rec loop = function
    | path::tl ->
        let abspath = Filename.concat path prog in
        if Sys.file_exists abspath then abspath
        else loop tl
    | [] ->
        raise Not_found
  in
  loop (dissect_path "PATH")

let time_string t =
  let open Unix in
  let tm = gmtime t in
  Printf.sprintf "%4d/%02d/%02d-%02d:%02d:%02d"
    (tm.tm_year + 1900)
    (tm.tm_mon + 1)
    tm.tm_mday
    tm.tm_hour
    tm.tm_min
    tm.tm_sec

let to_abs path =
  if not (Filename.is_relative path) then path
  else Filename.concat (Unix.getcwd()) path

let to_abs_cmds cmds =
  let prog = List.hd cmds in
  if not (Filename.is_relative prog) then cmds
  else (Filename.concat (Unix.getcwd()) prog) :: (List.tl cmds)

