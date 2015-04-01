(* ofuzz - ocaml fuzzing platform *)

(** surface-based mutational generator

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
open Comblib

let mutate_file r buf filesize rseed mratio =
  let mratio = get_ratio rseed mratio in
  let bits = filesize * 8 in
  let bits_to_mod = (float_of_int bits) *. mratio |> int_of_float in
  let bits_to_mod = if bits_to_mod = 0 then 1 else bits_to_mod in
  let set = floyds_sampling r bits bits_to_mod in
  Hashtbl.iter (fun bitpos _ ->
    let bitpos = bitpos - 1 in
    let byte_pos, bit_offset = bitpos / 8, bitpos mod 8 in
    let newval = 1 lsl bit_offset |> char_of_int in
    Fastlib.mod_file buf byte_pos newval
  ) set

let generate conf knobs rseed =
  let myfile, mapsize, filesize = prepare_fuzztarget conf true in
  let r = init_rseed rseed in
  let buf = Fastlib.map_file myfile mapsize in
  let () = mutate_file r buf filesize rseed conf.mratio in
  let () = Fastlib.unmap_file buf in
  myfile, rseed

