(* ofuzz - partition-based mutational fuzzing *)

(** fast library

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

(** File handler type *)
type file_t

(** [copy a b] copies file [a] to file [b] *)
val copy : string -> string -> unit

(** [exec cmds timeout oflag] executes a command line [cmds] up to [timeout]
    seconds, and returns a tuple (code, pid). If [oflag] is true, then the
    output of execution is shown. The return code is 0 if there is no error,
    otherwise it contains signal number that causes the program to crash.
*)
val exec : string array -> int -> bool -> int * int

(** mmap a file for a given name and a size *)
val map_file : string -> int -> file_t

(** munmap *)
val unmap_file : file_t -> unit

(** [mod_file f pos v] modifies the file [f] by applying xor to the character at
    [pos] with [v].
*)
val mod_file : file_t -> int -> char -> unit

(** Get a page-aligned size *)
val get_mapping_size : int -> int

(** [get_size_tuple f] returns a pair of a page-aligned file size and the
    actual file size from a given file path [f] *)
val get_size_tuple: string -> int * int

