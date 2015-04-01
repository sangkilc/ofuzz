(* ofuzz - ocaml fuzzing platform *)

(** common functions for the test-gen module

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
open Misc

type fuzz_target = string * int * int

(** memoize seedfile info:
    (original seed path, temporary seed path, mapped size, actual size)
 *)
let target_cache : ((string * string * int * int) option) array ref = ref [||]

let init_testgen confs =
  target_cache := Array.make (List.length confs) None

let seedfile_exists conf = conf.seed_file <> ""

let cache conf src dst mapsize filesize =
  !target_cache.(conf.confid) <- Some (src, dst, mapsize, filesize)

let compute_fuzztarget_from_seed conf =
  let src = conf.seed_file in
  let dst = List.nth conf.cmds conf.filearg_idx in
  let mapsize, filesize = Fastlib.get_size_tuple src in
  cache conf src dst mapsize filesize;
  src, dst, mapsize, filesize

let compute_fuzztarget_from_scratch conf =
  let src = "" in
  let dst = List.nth conf.cmds conf.filearg_idx in
  let filesize = conf.input_size in
  let mapsize = Fastlib.get_mapping_size filesize in
  cache conf src dst mapsize filesize;
  src, dst, mapsize, filesize

let compute_fuzztarget conf =
  if seedfile_exists conf then compute_fuzztarget_from_seed conf
  else compute_fuzztarget_from_scratch conf

let obtain_fuzztarget_path conf =
  match !target_cache.(conf.confid) with
  | None -> compute_fuzztarget conf
  | Some info -> info

let prepare_fuzztarget conf copy =
  let src, dst, mapsize, filesize = obtain_fuzztarget_path conf in
  if copy then (assert (src <> ""); Fastlib.copy src dst) else ();
  dst, mapsize, filesize

(* this ratio selection algorithm is taken from zzuf *)
let shuffle = [|0L;12L;2L;10L;14L;8L;15L;7L;9L;13L;3L;6L;4L;1L;11L;5L|]
let ratio_selection rseed ratio_begin ratio_end =
  let (<<%) = Int64.shift_left in
  let (>>%) = Int64.shift_right in
  let (|%) = Int64.logor in
  let (&%) = Int64.logand in
  let rate = shuffle.(rseed &% 0xfL |> Int64.to_int) <<% 12 in
  let rate = rate |% ((rseed &% 0xf0L) <<% 4) in
  let rate = rate |% ((rseed &% 0xf00L) >>% 4) in
  let rate = rate |% ((rseed &% 0xf000L) >>% 12) in
  let rate = Int64.to_float rate in
  let min = log ratio_begin in
  let max = log ratio_end in
  let cur = min +. (max -. min) *. rate /. (float 0xffff) in
  exp cur

let get_ratio rseed (ratio_begin, ratio_end) =
  if ratio_begin = ratio_end then ratio_begin
  else ratio_selection rseed ratio_begin ratio_end

let int64_to_int_array rseed =
  (* divide 64-bit into four 16-bit numbers *)
  let p1 = Int64.logand 0xFFFFL rseed |> Int64.to_int
  and p2 = Int64.logand 0XFFFFL (Int64.shift_right rseed 16) |> Int64.to_int
  and p3 = Int64.logand 0XFFFFL (Int64.shift_right rseed 32) |> Int64.to_int
  and p4 = Int64.logand 0XFFFFL (Int64.shift_right rseed 48) |> Int64.to_int in
  [|p1;p2;p3;p4|]

(* initialize based on the random seed *)
let init_rseed rseed =
  let rseed = int64_to_int_array rseed in
  Random.full_init rseed;
  Random.get_state ()

