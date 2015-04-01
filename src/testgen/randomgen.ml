(* ofuzz - ocaml fuzzing platform *)

(** random generator

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
open Fuzztypes
open Testgenlib
open Misc

let randbuf0_size = 256
let randbuf0 = Bytes.create randbuf0_size

let randbuf1_size = 8192
let randbuf1 = Bytes.create randbuf1_size

let random_char r =
  Random.State.int r 256 |> char_of_int

let random_output r randbuf ch =
  for i = 0 to (String.length randbuf - 1) do
    Bytes.set randbuf i (random_char r)
  done;
  output_string ch randbuf

let random_gen r myfile filesize =
  let rec gen_loop leftsize ch =
    if leftsize >= randbuf1_size then
      (random_output r randbuf1 ch; gen_loop (leftsize-randbuf1_size) ch)
    else if leftsize >= randbuf0_size then
      (random_output r randbuf0 ch; gen_loop (leftsize-randbuf0_size) ch)
    else if leftsize > 0 then
      (output_char ch (random_char r); gen_loop (leftsize-1) ch)
    else
      ()
  in
  let ch = open_out myfile in
  gen_loop filesize ch;
  close_out ch

let generate conf knobs rseed =
  let myfile, _mapsize, filesize = prepare_fuzztarget conf false in
  let r = init_rseed rseed in
  let () = random_gen r myfile filesize in
  myfile, rseed

