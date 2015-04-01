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

open Misc

let execute cmds timeout allow_output =
  Fastlib.exec cmds timeout allow_output (* TODO: handle stdin *)

let is_crashing = function
    | 11 -> Some "SIGSEGV"
    | 8 -> Some "SIGFPE"
    | 7 -> Some "SIGBUS"
    | 4 -> Some "SIGILL"
    | 6 (* SIGABRT *)
    | _ -> None

let set_coredump = Libfuzz.set_coredump

let cleanup_dir dirpath =
  if not (Sys.file_exists dirpath) then Unix.mkdir dirpath 0o777
  else Libfuzz.remove_dir_contents dirpath

let disable_x_redirection () =
  ignore (Sys.command "killall -9 Xvfb x11vnc 2> /dev/null")

let check_xredirection prog =
  if check_program_availability prog then ()
  else
    let msg = Printf.sprintf "Could not find %s for X redirection. \
                              See the manual for more details." prog
    in
    error_exit msg

let enable_x_redirection () =
  let () = disable_x_redirection () in
  let () = check_xredirection "Xvfb" in
  let () = check_xredirection "x11vnc" in
  let xvfbcmd = "Xvfb :42 -screen 0 1024x768x16 1> /dev/null 2> /dev/null &" in
  let _ = Sys.command xvfbcmd in
  let _ = Sys.command "x11vnc -display :42 -bg -nopw -listen localhost -xkb \
                       1> /dev/null 2> /dev/null"
  in
  Unix.putenv "DISPLAY" ":42"

let init_fuzzing_env path gui =
  let () = cleanup_dir path in
  let () = Unix.chdir path in
  let cwd = Unix.getcwd () in
  let () = set_coredump () in
  let () = if gui then enable_x_redirection () else () in
  cwd

