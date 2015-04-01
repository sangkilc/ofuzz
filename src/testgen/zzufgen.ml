(* ofuzz - ocaml fuzzing platform *)

(** zzuf generator

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
open Testgenlib
open Misc

let mutate_file buf filesize rseed mratio =
  let mratio = get_ratio rseed mratio in
  let () = Zzrandom.srand (Int64.to_int32 rseed) in
  let bits = (float_of_int (filesize * 8)) *. mratio in
  let bits_to_mod =
    let dither = 1000000.0 in
    let todo = bits *. dither in
    let todo =
      todo +. (Int32.to_float (Zzrandom.rand (Int32.of_float dither)))
    in
    int_of_float (todo /. dither)
  in
  let bits_to_mod = if bits_to_mod = 0 then 1 else bits_to_mod in
  let rec mod_loop cnt =
    if cnt <= 0 then ()
    else
      let pos = Zzrandom.rand (Int32.of_int filesize) |> Int32.to_int in
      let r = Zzrandom.rand 8l |> Int32.to_int in
      let newval = 1 lsl r in
      let newval = char_of_int newval in
      Fastlib.mod_file buf pos newval;
      mod_loop (cnt-1)
  in
  mod_loop bits_to_mod

let generate conf knobs rseed =
  let myfile, mapsize, filesize = prepare_fuzztarget conf true in
  let buf = Fastlib.map_file myfile mapsize in
  let () = mutate_file buf filesize rseed conf.mratio in
  let () = Fastlib.unmap_file buf in
  myfile, rseed

