(* ofuzz - ocaml fuzzing platform *)

(** fuzzing interface

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
open Optmanager
open Curses
open Misc

let errcheck msg = function
  | true -> ()
  | false -> endwin (); failwith msg

let check_screen_size (height, width) =
  if width < 60 then failwith "terminal width must be greater than 80"
  else if height < 25 then failwith "terminal height must be greater than 25"
  else ()

let check_colors = errcheck "terminal must support colors"
let check_addstr = errcheck "addstr failure"
let check_refresh = errcheck "refresh failure"
let check_cursor = errcheck "cursor error"

let print_num_right wnd height n =
  let n = Printf.sprintf "%d" n in
  mvwaddstr wnd height (30 - (String.length n)) n |> check_addstr

let greenblack = 1
let redblack = 2
let blueblack = 3
let whiteblack = 4

let init_interface knobs =
  let wnd = initscr () in
  let height, width = get_size () in
  check_screen_size (height, width);
  has_colors () |> check_colors;
  start_color () |> check_colors;
  curs_set 0 |> check_cursor;
  (* colors *)
  init_pair greenblack 2 0 |> check_colors;
  init_pair redblack 1 0 |> check_colors;
  init_pair blueblack 4 0 |> check_colors;
  init_pair whiteblack 7 0 |> check_colors;
  (* drawing *)
  attron (A.color_pair greenblack lor A.bold);
  mvwaddstr wnd 0 2 (Printf.sprintf "OFuzz %s" (Ofuzzversion.string ()))
  |> check_addstr;
  attroff (A.bold);
  attron (A.color_pair blueblack);
  mvhline 1 1 0 (width-2);
  attron (A.color_pair whiteblack);
  mvwaddstr wnd 2 2 "Target: " |> check_addstr;
  mvwaddstr wnd 4 2 (Printf.sprintf "Started at ") |> check_addstr;
  attron (A.color_pair blueblack);
  mvhline 5 1 0 (width-2);
  attron (A.color_pair whiteblack);
  mvwaddstr wnd 6 2 "#Runs:" |> check_addstr; print_num_right wnd 6 0;
  attron (A.bold);
  mvwaddstr wnd 7 2 "#Bugs:" |> check_addstr;
  attron (A.color_pair redblack);
  print_num_right wnd 7 0;
  attroff (A.bold);
  attron (A.color_pair whiteblack);
  mvwaddstr wnd 8 2 "#Crashes:" |> check_addstr; print_num_right wnd 8 0;
  attron (A.color_pair blueblack);
  mvhline 3 1 0 (width-2);
  attron (A.color_pair whiteblack);
  mvwaddstr wnd 4 42 ("Conf") |> check_addstr;
  let sch = schedule_to_string knobs.scheduling in
  mvwaddstr wnd 6 42 (Printf.sprintf "Scheduling: %s" sch) |> check_addstr;
  let triage = if knobs.triage_on_the_fly then "on" else "off" in
  mvwaddstr wnd 7 42 (Printf.sprintf "Triage:     %s" triage) |> check_addstr;
  refresh () |> check_refresh;
  wnd

let destroy_interface () =
  endwin ()

let update_interval = 1.0 (* interface update interval *)

let update_status stat conf wnd =
  let uniq = Hashtbl.length stat.unique_set in
  let t = Unix.localtime stat.start_time in
  let time =
    Printf.sprintf "%02d:%02d:%02d-%02d/%02d"
      t.Unix.tm_hour t.Unix.tm_min t.Unix.tm_sec
      (t.Unix.tm_mon + 1) t.Unix.tm_mday
  in
  attron (A.color_pair blueblack);
  mvwaddstr wnd 2 10 conf.cmds_array.(0) |> check_addstr;
  attron (A.color_pair whiteblack);
  print_num_right wnd 6 stat.num_runs;
  attron (A.color_pair redblack lor A.bold);
  print_num_right wnd 7 uniq;
  attroff (A.bold);
  attron (A.color_pair whiteblack);
  print_num_right wnd 8 stat.num_crashes;
  mvwaddstr wnd 4 13 time |> check_addstr;
  mvwaddstr wnd 4 47 (Printf.sprintf "(%d)" conf.confid) |> check_addstr;
  refresh () |> check_refresh

