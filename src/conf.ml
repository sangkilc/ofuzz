(* ofuzz - ocaml fuzzing platform *)

(** fuzz configuration

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
open Yojson.Safe
open Misc

(** exception: json parsing error *)
exception WrongFormat of string

let get_conflist = function
  | `List obj -> obj
  | _ -> raise (WrongFormat "must contain a list of confs")

let unwrap_assoc = function
  | `Assoc lst -> lst
  | _ -> raise (WrongFormat "conf must be a valid JSON object")

let parse_cmds cmds args =
  let mapper = function
    | `String cmd -> cmd
    | _ -> raise (WrongFormat "invalid cmd arg")
  in
  if List.length cmds > 0 then raise (WrongFormat "duplicated cmds")
  else List.map mapper args

let get_cmds cmds =
  if List.length cmds = 0 then raise (WrongFormat "cmds not given")
  else cmds

let cmdopt name = function
  | None -> raise (WrongFormat (name^" not given"))
  | Some arg -> arg

let construct_conf id cmds filearg mratio_s mratio_e seed_file =
  let cmds = get_cmds cmds |> to_abs_cmds in
  let prog = List.hd cmds in
  let filearg = cmdopt "filearg" filearg in
  let mratio_s = cmdopt "mratiostart" mratio_s in
  let mratio_e = try cmdopt "mratioend" mratio_e with _ -> mratio_s in
  let seed_file = cmdopt "seed_file" seed_file |> to_abs in
  let input_size =
    try get_filesize seed_file
    with _ -> raise (WrongFormat "seed file not found")
  in
  (* sanitization *)
  if filearg >= List.length cmds then
    raise (WrongFormat "invalid filearg")
  else if not (check_program_availability prog) then
    raise (WrongFormat "invalid program given")
  else if input_size = 0 then
    raise (WrongFormat "seed file is empty")
  else
    {
      confid = id;
      cmds = cmds;
      cmds_array = Array.of_list cmds;
      filearg_idx = filearg;
      mratio = (mratio_s, mratio_e);
      seed_file = seed_file;
      part_file = "";
      input_size = input_size;
    }

let parse_conf json id =
  let assoc = unwrap_assoc json in
  let rec parse_loop cmds filearg ratio_s ratio_e seedfile = function
    | ("cmds", `List args)::tl ->
        parse_loop (parse_cmds cmds args) filearg ratio_s ratio_e seedfile tl
    | ("filearg", `Int idx)::tl ->
        parse_loop cmds (Some idx) ratio_s ratio_e seedfile tl
    | ("mratiostart", `Float ratio)::tl ->
        parse_loop cmds filearg (Some ratio) ratio_e seedfile tl
    | ("mratioend", `Float ratio)::tl ->
        parse_loop cmds filearg ratio_s (Some ratio) seedfile tl
    | ("seedfile", `String seed)::tl ->
        parse_loop cmds filearg ratio_s ratio_e (Some seed) tl
    | [] ->
        construct_conf id cmds filearg ratio_s ratio_e seedfile
    | (form, json)::_ ->
        Printf.eprintf "(%s, %s)\n" form (to_string json);
        raise (WrongFormat "unknown format")
  in
  parse_loop [] None None None None assoc

let parse_json json =
  let per_conf acc obj =
    let conf = parse_conf obj (List.length acc) in
    conf::acc
  in
  let lst = get_conflist json in
  List.fold_left per_conf [] lst

let parse file =
  if not (Sys.file_exists file) then raise Not_found else ();
  let ch = open_in file in
  let json = from_channel ch in
  close_in ch;
  parse_json json

