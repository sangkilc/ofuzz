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

exception Overflow

module AddrSet : Set.S with type elt = nativeint
module AddrMap : Map.S with type key = nativeint
module StringSet : Set.S with type elt = string
module StringMap : Map.S with type key = string
module IntMap : Map.S with type key = int
module IntSet : Set.S with type elt = int

(** Read lines from a file *)
val readlines : string -> string list

(** Exit with showing an error message *)
val error_exit : string -> 'a

(** Piping *)
val (|>) : 'a -> ('a -> 'b) -> 'b

(** Get file size *)
val get_filesize : string -> int

(** Check if a program is accessible from the current cmdline *)
val check_program_availability : string -> bool

(** Obtain an absolute path of a binary by resolving PATH environment *)
val get_abspath_for_bin : string -> string

(** Unix.time() float to string *)
val time_string : float -> string

(** Transform a relative path to an absolute path based on the CWD *)
val to_abs : string -> string

(** Transform a command line to have an absolute program name (the first arg)
    based on the CWD *)
val to_abs_cmds : string list -> string list

(** Unlink a file if it exists *)
val rm_if_exists : string -> unit

