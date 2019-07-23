(************************************************************************)
(*                                TzScan                                *)
(*                                                                      *)
(*  Copyright 2017-2018 OCamlPro                                        *)
(*                                                                      *)
(*  This file is distributed under the terms of the GNU General Public  *)
(*  License as published by the Free Software Foundation; either        *)
(*  version 3 of the License, or (at your option) any later version.    *)
(*                                                                      *)
(*  TzScan is distributed in the hope that it will be useful,           *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of      *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the       *)
(*  GNU General Public License for more details.                        *)
(*                                                                      *)
(************************************************************************)

module Tezos_types = Ocplib_tezos.Tezos_types

type net =
  | Alphanet
  | Zeronet
  | Betanet

val net : net

val tez_units : int64

(* This value is statically known at build time *)
val versions : Data_types.versions

(* These values are only available after downloading them from the
   API server and the WWW server *)
val api : Data_types.api_server_info
val www : Data_types.www_server_info

(* init and update constants list *)
val init_constants : (int * Tezos_types.constants) list -> unit
val add_constants : int -> Tezos_types.constants -> unit

(* `constants ~cycle` returns the constants for `cycle` *)
val constants : cycle:int -> Tezos_types.constants

(* `save_api_config filename` save current configuration into `filename` *)
val save_api_config : string -> unit

val cycle_from_level : cst:Tezos_types.constants -> int -> int
