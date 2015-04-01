(* ofuzz - ocaml fuzzing platform *)

(** database control

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
open Mysql
open Fuzztypes
open Optmanager
open Fuzzing
open Misc

let errmsg_to_string = function
  | Some msg -> msg
  | None -> "unknown"

let mysql_exec dbhandle cmds =
  let res = exec dbhandle cmds in
  match status dbhandle with
  | StatusError _ ->
      let msg = errmsg dbhandle |> errmsg_to_string in
      let err = Printf.sprintf "MySQL Error: %s\n" msg in
      failwith err
  | _ -> res

let strip errmsg = function
  | Some s -> s
  | None -> failwith errmsg

let get_int_result errmsg res =
  match fetch res with
  | None -> failwith errmsg
  | Some row -> strip errmsg row.(0) |> int_of_string

let null = "NULL"
let null_str dbhandle = ml2rstr dbhandle ""

let bool_to_tinyint = function
  | true -> 1
  | false -> 0

let get_insert_id dbhandle =
  let res = mysql_exec dbhandle "SELECT LAST_INSERT_ID();" in
  get_int_result "failed to get insert id" res

let bz_block_size = 921600 (* 900K *)

let rec reader bzch inch buf pos total =
  let full_pass = (total - pos) >= bz_block_size in
  let read_size = if full_pass then bz_block_size else total - pos in
  Pervasives.really_input inch buf 0 read_size;
  Bz2.write bzch buf 0 read_size;
  if full_pass then reader bzch inch buf (pos + bz_block_size) total
  else ()

let bzip_a_file origin bzfile =
  let inch = Pervasives.open_in origin in
  let outch = Pervasives.open_out bzfile in
  let bzch = Bz2.open_out outch in
  let n = in_channel_length inch in
  let buf = Bytes.create bz_block_size in
  reader bzch inch buf 0 n;
  Bz2.close_out bzch;
  Pervasives.close_out outch;
  Pervasives.close_in inch

let load_blob state =
  let logfile = get_logfile state.working_dir in
  let bzfile = Filename.concat (Filename.dirname logfile) "log.bz2" in
  let () = bzip_a_file logfile bzfile in
  let ch = open_in bzfile in
  let n = in_channel_length ch in
  let s = Bytes.create n in
  really_input ch s 0 n;
  close_in ch;
  s

let insert_campaign state dbhandle =
  let log = load_blob state in
  let _ = mysql_exec dbhandle
    (Printf.sprintf "INSERT INTO campaign_tbl VALUES %s;"
      (values [null_str dbhandle;
               ml2rstr dbhandle (time_string state.initial_time);
               ml2rstr dbhandle (schedule_to_string state.knobs.scheduling);
               ml2rblob dbhandle log])
    )
  in
  get_insert_id dbhandle |> ml2int

let insert_client state dbhandle =
  let new_client state dbhandle =
    let _ = mysql_exec dbhandle
      (Printf.sprintf "INSERT INTO client_tbl VALUES %s"
        (values [null_str dbhandle;
                 ml2rstr dbhandle Envmanager.os;
                 ml2rstr dbhandle Envmanager.kernel;
                 ml2rstr dbhandle Envmanager.arch;
                 ml2rstr dbhandle Envmanager.cpu;
                 ml2rstr dbhandle Envmanager.version])
      )
    in
    get_insert_id dbhandle
  in
  let res = mysql_exec dbhandle
    (Printf.sprintf "SELECT uClientId FROM client_tbl \
                     WHERE strOS=%s \
                       AND strKernel=%s \
                       AND strArch=%s \
                       AND strCPU=%s \
                       AND strVersion=%s;"
      (ml2rstr dbhandle Envmanager.os)
      (ml2rstr dbhandle Envmanager.kernel)
      (ml2rstr dbhandle Envmanager.arch)
      (ml2rstr dbhandle Envmanager.cpu)
      (ml2rstr dbhandle Envmanager.version)
    )
  in
  let cid =
    if size res > 0L then get_int_result "failed to get a client id" res
    else new_client state dbhandle
  in
  ml2int cid

let insert_seed dbhandle conf =
  let seed_hash = Digest.file conf.seed_file |> Digest.to_hex in
  let new_seed dbhandle conf =
    let _ = mysql_exec dbhandle
      (Printf.sprintf "INSERT INTO seed_tbl VALUES %s"
        (values [null_str dbhandle;
                 ml2int conf.input_size;
                 ml2rstr dbhandle conf.seed_file;
                 ml2rstr dbhandle seed_hash])
      )
    in
    get_insert_id dbhandle
  in
  let res = mysql_exec dbhandle
    (Printf.sprintf "SELECT uSeedId FROM seed_tbl \
                     WHERE uFileSize=%s \
                       AND strFileName=%s \
                       AND strFileHash=%s;"
      (ml2int conf.input_size)
      (ml2rstr dbhandle conf.seed_file)
      (ml2rstr dbhandle seed_hash)
    )
  in
  let sid =
    if size res > 0L then get_int_result "failed to get a seed id" res
    else new_seed dbhandle conf
  in
  ml2int sid

let insert_program dbhandle conf =
  let prog_path = List.hd conf.cmds in
  let prog_name = Filename.basename prog_path in
  let prog_hash = Digest.file prog_path |> Digest.to_hex in
  let prog_size = get_filesize prog_path in
  let new_prog dbhandle conf =
    let _ = mysql_exec dbhandle
      (Printf.sprintf "INSERT INTO program_tbl VALUES %s"
        (values [null_str dbhandle;
                 ml2int prog_size;
                 ml2rstr dbhandle prog_name;
                 ml2rstr dbhandle prog_hash])
      )
    in
    get_insert_id dbhandle
  in
  let res = mysql_exec dbhandle
    (Printf.sprintf "SELECT uProgId FROM program_tbl \
                     WHERE uProgSize=%s \
                       AND strProgName=%s \
                       AND strProgHash=%s;"
      (ml2int prog_size)
      (ml2rstr dbhandle prog_name)
      (ml2rstr dbhandle prog_hash)
    )
  in
  let pid =
    if size res > 0L then get_int_result "failed to get a seed id" res
    else new_prog dbhandle conf
  in
  ml2int pid

let insert_conf state dbhandle conf sid pid =
  let seed_start, seed_end = state.knobs.seed_range in
  let mratio_start, mratio_end = conf.mratio in
  let _ = mysql_exec dbhandle
    (Printf.sprintf "INSERT INTO fuzz_conf_tbl VALUES %s"
      (values [null_str dbhandle;
               ml2rstr dbhandle (alg_to_string state.knobs.testgen_alg);
               ml2rstr dbhandle (String.concat " " conf.cmds);
               ml2float mratio_start;
               ml2float mratio_end;
               sid;
               pid;
               ml2int conf.input_size;
               ml2int state.knobs.verbosity;
               ml2int state.knobs.timeout;
               ml2int state.knobs.round_timeout;
               ml2int state.knobs.exec_timeout;
               ml642int seed_start;
               ml642int seed_end;
               ml642int state.rseed;
               bool_to_tinyint state.knobs.triage_on_the_fly |> ml2int;
               bool_to_tinyint state.knobs.gen_crash_tcs |> ml2int;
               bool_to_tinyint state.knobs.gen_all_tcs |> ml2int])
    )
  in
  get_insert_id dbhandle |> ml2int

let insert_fuzzing dbhandle stats conf cpid clid cfid =
  let _ = mysql_exec dbhandle
    (Printf.sprintf "INSERT INTO fuzzing_tbl VALUES %s"
      (values [null_str dbhandle;
               ml2rstr dbhandle (time_string stats.(conf.confid).start_time);
               ml2rstr dbhandle (time_string stats.(conf.confid).finish_time);
               clid;
               cpid;
               cfid])
    )
  in
  get_insert_id dbhandle |> ml2int

let insert_stats dbhandle stats conf fid =
  let _ = mysql_exec dbhandle
    (Printf.sprintf "INSERT INTO stats_tbl VALUES %s"
      (values [null_str dbhandle;
               ml2int (Hashtbl.length stats.(conf.confid).unique_set);
               ml2int stats.(conf.confid).num_crashes;
               ml2int stats.(conf.confid).num_runs;
               ml2int (int_of_float stats.(conf.confid).time_spent);
               fid])
    )
  in
  get_insert_id dbhandle |> ml2int

let insert_crash_case dbhandle stats conf stid =
  let new_crash dbhandle crashid =
    let _ = mysql_exec dbhandle
      (Printf.sprintf "INSERT INTO crash_case_tbl VALUES %s"
        (values [null_str dbhandle;
                 ml2rstr dbhandle crashid.hashval;
                 ml2rstr dbhandle crashid.backtrace])
      )
    in
    get_insert_id dbhandle
  in
  Hashtbl.iter (fun _ crashid ->
    let res = mysql_exec dbhandle
      (Printf.sprintf "SELECT uCrashId FROM crash_case_tbl \
                       WHERE strCrashHash=%s;"
        (ml2rstr dbhandle crashid.hashval)
      )
    in
    let ccid =
      if size res > 0L then get_int_result "failed to get a crashcase id" res
      else new_crash dbhandle crashid
    in
    let ccid = ml2int ccid in
    let _ = mysql_exec dbhandle
      (Printf.sprintf "INSERT IGNORE INTO crash_stat_tbl VALUES %s"
        (values [stid; ccid])
      )
    in
    ()
  ) stats.(conf.confid).unique_set

let insert_crash_case dbhandle state conf stid =
  if state.knobs.triage_on_the_fly then
    insert_crash_case dbhandle state.stats conf stid
  else ()

let insert_per_conf with_seed state dbhandle confs cpid clid =
  List.iter (fun conf ->
    let sid =
      if with_seed then insert_seed dbhandle conf
      else null
    in
    let pid = insert_program dbhandle conf in
    let cfid = insert_conf state dbhandle conf sid pid in
    let fid = insert_fuzzing dbhandle state.stats conf cpid clid cfid in
    let stid = insert_stats dbhandle state.stats conf fid in
    insert_crash_case dbhandle state conf stid
  ) confs

let insert_per_conf state dbhandle confs cpid clid =
  match state.knobs.testgen_alg with
  | BallMutational | SurfaceMutational | ZzufMutational ->
      insert_per_conf true state dbhandle confs cpid clid
  | _ ->
      insert_per_conf false state dbhandle confs cpid clid

let push_result state dbhandle confs =
  let _ = mysql_exec dbhandle "START TRANSACTION;" in
  let cpid = insert_campaign state dbhandle in
  let clid = insert_client state dbhandle in
  let _ = insert_per_conf state dbhandle confs cpid clid in
  let _ = mysql_exec dbhandle "COMMIT;" in
  ()

let push_result state confs =
  let dbhandle = dbconnect state.knobs in
  match dbhandle with
  | None -> ()
  | Some dbhandle -> push_result state dbhandle confs

