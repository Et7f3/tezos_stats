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

open Data_types
module Misc = Tzscan_misc.Misc

let find_field header_all fields_all elt =
  let rec aux = function
    | [], _ | _, [] -> None
    | hh :: _, hf :: _ when hh = elt -> Some hf
    | _ :: th, _ :: tf -> aux (th, tf) in
  let res = aux (header_all, fields_all) in
  res

let choose_fields header_all fields_all header =
  List.rev @@ List.fold_left (fun acc elt ->
      match find_field header_all fields_all elt with
      | None -> acc
      | Some field -> field :: acc
    ) [] header

let transaction_header =
  ["transaction"; "block"; "network"; "source"; "destination"; "amount"; "fee";
   "date"; "parameters"; "failed"; "internal"; "burned tez"; "counter"; "gas limit";
   "storage limit"]

let transaction header o =
  List.rev @@
  match o.op_type with
  | Sourced sos ->
    begin match sos with
      | Manager (_, source, l) ->
        (List.fold_left (fun acc op -> match op with
             | Transaction tr ->
               ( choose_fields transaction_header
                   [ o.op_hash; o.op_block_hash; o.op_network_hash; source.tz ;
                     tr.tr_dst.tz;
                     Int64.to_string tr.tr_amount;
                     Int64.to_string tr.tr_fee;
                     tr.tr_timestamp;
                     Misc.unopt "" tr.tr_parameters;
                     string_of_bool tr.tr_failed;
                     string_of_bool tr.tr_internal;
                     Int64.to_string tr.tr_burn;
                     Int32.to_string tr.tr_counter;
                     Z.to_string tr.tr_gas_limit;
                     Z.to_string tr.tr_storage_limit ] header ) :: acc
             | _ -> acc) [] l)
      | _ -> [] end
  | _ -> []

let rewards_history_header = [
  "cycle"; "nb_delegators"; "staking_balance"; "baking_rights"; "endorsing_rights";
  "block_rewards"; "endorsement_rewards"; "fees";
  "nonce_tips"; "nonce_lost_rewards"; "nonce_lost_fees";
  "denounciation_rewards"; "denonciation_lost_rewards"; "denonciation_lost_fees";
  "denonciation_lost_deposits"; "status" ]

let status_str = function
  | Cycle_in_progress -> "in progress"
  | Cycle_pending -> "pending"
  | Rewards_pending -> "rewards pending"
  | Rewards_delivered -> "rewards delivered"

let rewards_history header rw =
  List.map (fun ars ->
      choose_fields rewards_history_header [
        string_of_int ars.ars_cycle; string_of_int ars.ars_delegators_nb;
        Int64.to_string ars.ars_delegate_staking_balance;
        Int64.to_string ars.ars_baking_rights_rewards;
        Int64.to_string ars.ars_endorsing_rights_rewards;
        Int64.to_string ars.ars_block_rewards;
        Int64.to_string ars.ars_endorsement_rewards;
        Int64.to_string ars.ars_fees;
        Int64.to_string ars.ars_rv_rewards;
        Int64.to_string ars.ars_rv_lost_rewards;
        Int64.to_string ars.ars_rv_lost_fees;
        Int64.to_string ars.ars_gain_from_denounciation;
        Int64.to_string ars.ars_lost_rewards;
        Int64.to_string ars.ars_lost_fees;
        Int64.to_string ars.ars_lost_deposit;
        status_str ars.ars_status
      ] header) rw
