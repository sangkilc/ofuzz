(* ofuzz - ocaml fuzzing platform *)

(** fuzzing apis

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

(** [execute cmds timeout oflag] executes a command line [cmds] up to [timeout]
    seconds, and returns a tuple (code, pid). If [oflag] is true, then the
    output of execution is shown. The return code is 0 if there is no error,
    otherwise it contains signal number that causes the program to crash.
*)
val execute : string array -> int -> bool -> int * int

(** Checks the exit code of [execute], and returns Some s where s is a
    signal string for crash. If there is no crash, then it returns None. *)
val is_crashing : int -> string option

(** Enable coredump *)
val set_coredump : unit -> unit

(** Remove all contents of a given directory, and (or) create a new empty
    directory. *)
val cleanup_dir : string -> unit

(** Enable X redirection *)
val enable_x_redirection : unit -> unit

(** Disable X redirection *)
val disable_x_redirection : unit -> unit

(** Initialize the basic fuzzing environment *)
val init_fuzzing_env : string -> bool -> string

