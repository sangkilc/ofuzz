(* ofuzz - ocaml fuzzing platform *)

(** test-eval module

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
open Fuzzlib
open Triage
open Optmanager
open Logger
open Misc

(** Test-eval algorithm *)
module type TestEvalAlg =
sig
  val triage : int
            -> Optmanager.knobs
            -> bool
            -> string
            -> string list
            -> input
            -> fuzzresult
end

module type TestEval =
sig
  val evaluate : fuzzconf -> Optmanager.knobs -> bool -> input -> fuzzresult
end

module TestEval =
  functor (Alg: TestEvalAlg) ->
struct

  let evaluate conf knobs triage_verbose input =
    let code, pid =
      execute conf.cmds_array knobs.exec_timeout knobs.full_debugging
    in
    match is_crashing code with
    | Some reason -> Alg.triage pid knobs triage_verbose reason conf.cmds input
    | None -> Normal

end

module CrashEvalBySafeStack = TestEval (SafeStack)

