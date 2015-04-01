(* ofuzz - partition-based mutational fuzzing *)

(** data structures
    - priority queue

    @author Sang Kil Cha <sangkil.cha\@gmail.com>
    @since  2013-12-06

 *)

(*
Copyright (c) 2013, Sang Kil Cha
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

module type PRIOQUEUE =
sig

  type priority = int

  type 'a queue = Empty | Node of priority * 'a * 'a queue * 'a queue

  val empty : 'a queue
  val is_empty : 'a queue -> bool
  val insert : 'a queue -> priority -> 'a -> 'a queue
  val extract : 'a queue -> priority * 'a * 'a queue
  val mergeable : 'a queue -> bool

  exception Empty_Queue

end

module PRIOQUEUE =
struct

  exception Empty_Queue

  (* higher priority means higher chance of being populated *)
  type priority = int

  type 'a queue = Empty | Node of priority * 'a * 'a queue * 'a queue

  let empty = Empty

  let is_empty = function
    | Empty -> true
    | Node _ -> false

  let rec insert queue prio elt =
    match queue with
    | Empty -> Node(prio, elt, Empty, Empty)
    | Node(p, e, left, right) ->
          if prio > p then Node(prio, elt, insert right p e, left)
          else Node(p, e, insert right prio elt, left)

  let rec remove_top = function
    | Empty -> raise Empty_Queue
    | Node(prio, elt, left, Empty) -> left
    | Node(prio, elt, Empty, right) -> right
    | Node(prio, elt, (Node(lprio, lelt, _, _) as left),
                      (Node(rprio, relt, _, _) as right)) ->
        if lprio > rprio then Node(lprio, lelt, remove_top left, right)
        else Node(rprio, relt, left, remove_top right)

  let extract = function
    | Empty -> raise Empty_Queue
    | Node(prio, elt, _, _) as queue -> (prio, elt, remove_top queue)

  let min_priority = Pervasives.min_int
  let max_priority = Pervasives.max_int

  (* needs be more than 2 elements (>= 2) *)
  let mergeable = function
    | Empty -> false
    | Node(_prio, _elt, Empty, Empty) -> false
    | Node(_prio, _elt, _left, Empty) -> true
    | Node(_prio, _elt, Empty, _right) -> true
    | Node(_prio, _elt, (Node(_,_,_,_)),
                      (Node(_,_,_,_))) -> true

end

