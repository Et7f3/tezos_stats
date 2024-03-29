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

open Json_encoding
open Data_types
open Tezos_types
module Misc = Tzscan_misc.Misc
module Tezos_encoding = Ocplib_tezos.Tezos_encoding
module Tezos_utils = Ocplib_tezos.Tezos_utils

let int64 = EzEncoding.int64
let tez = EzEncoding.int64
let int = EzEncoding.int

let z_encoding = Tezos_encoding.z_encoding

let account_name_encoding =
  def "account_name"
    ~title:"Account Name"
    ~description:"Address and alias of an account" @@
  conv
    (fun {tz; alias} -> (tz, alias))
    (fun (tz, alias) -> {tz; alias})
    (obj2
       (req "tz" string)
       (opt "alias" string))

module Micheline = Tezos_encoding.Micheline

module V1 = struct

  module Op = struct

    let transaction_encoding =
      def "transaction"
        ~title:"Transaction"
        ~description:"Tezos transaction" @@
      conv
        (fun { tr_src; tr_amount; tr_counter ; tr_fee ; tr_gas_limit ; tr_storage_limit ;
               tr_dst; tr_parameters ; tr_failed ;
               tr_internal ; tr_burn; tr_op_level; tr_timestamp } ->
          let tr_parameters = match tr_parameters with
            | None -> None
            | Some p -> Some p in
          ("transaction", tr_src, tr_amount, tr_dst, None, tr_parameters,
           tr_failed, tr_internal, tr_burn, tr_counter, tr_fee, tr_gas_limit,
           tr_storage_limit, tr_op_level, tr_timestamp))
        (fun (_k, tr_src, tr_amount, tr_dst, p, str_p, tr_failed, tr_internal,
              tr_burn, tr_counter, tr_fee, tr_gas_limit, tr_storage_limit,
              tr_op_level, tr_timestamp) ->
          let tr_parameters =  match p, str_p with
            | None, None -> None
            | Some mic, None -> Some (Micheline.encode mic)
            | None, Some mic_str -> Some mic_str
            | _, _ -> assert false in
          { tr_src; tr_amount; tr_counter ; tr_fee ; tr_gas_limit ; tr_storage_limit ;
            tr_dst; tr_parameters; tr_failed ; tr_internal ; tr_burn; tr_op_level;
            tr_timestamp })
        (EzEncoding.obj15
           (req "kind" string)
           (req "src" account_name_encoding)
           (req "amount" tez)
           (req "destination" account_name_encoding)
           (opt "parameters" Micheline.script_expr_encoding)
           (opt "str_parameters" string)
           (req "failed" bool)
           (req "internal" bool)
           (req "burn" tez)
           (req "counter" int32)
           (req "fee" int64)
           (req "gas_limit" z_encoding)
           (req "storage_limit" z_encoding)
           (req "op_level" int)
           (req "timestamp" string))

    let reveal_encoding =
      def "reveal"
        ~title:"Reveal"
        ~description:"Tezos reveal" @@
      conv
        (fun { rvl_src; rvl_pubkey; rvl_counter; rvl_fee; rvl_gas_limit;
               rvl_storage_limit; rvl_failed; rvl_internal; rvl_op_level;
               rvl_timestamp }
          -> ("reveal", rvl_src, rvl_pubkey, rvl_counter, rvl_fee, rvl_gas_limit,
              rvl_storage_limit, rvl_failed, rvl_internal, rvl_op_level,
              rvl_timestamp))
        (fun (_k, rvl_src, rvl_pubkey, rvl_counter, rvl_fee, rvl_gas_limit,
              rvl_storage_limit, rvl_failed, rvl_internal, rvl_op_level,
              rvl_timestamp)
          -> { rvl_src; rvl_pubkey; rvl_counter; rvl_fee; rvl_gas_limit;
               rvl_storage_limit; rvl_failed; rvl_internal; rvl_op_level;
               rvl_timestamp })
        (EzEncoding.obj11
           (req "kind" string)
           (req "src" account_name_encoding)
           (req "public_key" string)
           (req "counter" int32)
           (req "fee" int64)
           (req "gas_limit" z_encoding)
           (req "storage_limit" z_encoding)
           (req "failed" bool)
           (req "internal" bool)
           (req "op_level" int)
           (req "timestamp" string))

    let origination_encoding =
      def "origination"
        ~title:"Origination"
        ~description:"Tezos origination" @@
      conv
        (fun { or_src ; or_manager ; or_delegate ; or_script ; or_spendable ;
               or_delegatable ; or_balance ; or_counter ; or_fee ;
               or_gas_limit ; or_storage_limit ; or_tz1 ;
               or_failed ; or_internal ; or_burn; or_op_level;
               or_timestamp } ->
          let str_script = match or_script with
            | None -> None
            | Some code ->
              Some (code.sc_code,
                    code.sc_storage) in
          let or_delegate =
            if or_delegate.tz = "" then None else Some or_delegate in
          ("origination", or_src, or_manager, or_balance, Some or_spendable,
           Some or_delegatable, or_delegate, None, Some or_tz1, str_script,
           or_failed, or_internal, or_burn,
           or_counter, or_fee, or_gas_limit, or_storage_limit,
           or_op_level, or_timestamp))
        (fun (_k, or_src, or_manager, or_balance, or_spendable,
              or_delegatable, or_delegate, script, or_tz1, str_script,
              or_failed, or_internal, or_burn,
              or_counter, or_fee, or_gas_limit, or_storage_limit,
              or_op_level, or_timestamp) ->
          let or_tz1 = Utils.unopt or_tz1 ~default:{tz="";alias=None} in
          let or_delegate = Utils.unopt or_delegate ~default:{tz="";alias=None} in
          let or_spendable = Utils.unopt or_spendable ~default:false in
          let or_delegatable = Utils.unopt or_delegatable ~default:false in
          let or_script = match script, str_script with
            | None, None -> None
            | Some (sc_code, sc_storage), None ->
              (* Orignation from Tezos Node *)
              let sc_code = Micheline.encode sc_code in
              let sc_storage = Micheline.encode sc_storage in
              Some { Tezos_types.sc_code ;
                     Tezos_types.sc_storage }
            | None, Some (sc_code, sc_storage) ->
              Some { Tezos_types.sc_code ;
                     Tezos_types.sc_storage }
            | _, _ -> assert false
          in
          { or_src; or_manager; or_delegate; or_script; or_spendable;
            or_delegatable; or_balance; or_counter; or_fee; or_gas_limit;
            or_storage_limit; or_tz1; or_failed; or_internal; or_burn;
            or_op_level; or_timestamp})
        (EzEncoding.obj19
           (req "kind" string)
           (req "src" account_name_encoding)
           (req "managerPubkey" account_name_encoding)
           (req "balance" tez)
           (opt "spendable" bool)
           (opt "delegatable" bool)
           (opt "delegate" account_name_encoding)
           (opt "script" Micheline.script_encoding)
           (* ocp field *)
           (opt "tz1" account_name_encoding)
           (opt "str_script" Micheline.script_str_encoding)
           (req "failed" bool)
           (req "internal" bool)
           (req "burn_tez" tez)
           (req "counter" int32)
           (req "fee" int64)
           (req "gas_limit" z_encoding)
           (req "storage_limit" z_encoding)
           (req "op_level" int)
           (req "timestamp" string))

    let delegation_encoding =
      def "delegation"
        ~title:"Delegation"
        ~description:"Tezos delegation" @@
      conv
        (fun { del_src ; del_delegate ; del_counter ; del_fee ;
               del_gas_limit ; del_storage_limit ;
               del_failed ; del_internal; del_op_level; del_timestamp } ->
          let del_delegate =
            if del_delegate.tz = "" then None else Some del_delegate in
          ("delegation", del_src, del_delegate, del_counter, del_fee,
           del_gas_limit, del_storage_limit, del_failed, del_internal,
           del_op_level, del_timestamp))
        (fun (_k, del_src, del_delegate, del_counter, del_fee, del_gas_limit,
              del_storage_limit, del_failed, del_internal, del_op_level,
              del_timestamp) ->
          let del_delegate = Utils.unopt del_delegate ~default:{tz="";alias=None} in
          { del_src ; del_delegate ; del_counter ; del_fee ; del_gas_limit ;
            del_storage_limit ; del_failed ; del_internal; del_op_level;
            del_timestamp })
        (EzEncoding.obj11
           (req "kind" string)
           (req "src" account_name_encoding)
           (opt "delegate" account_name_encoding)
           (req "counter" int32)
           (req "fee" int64)
           (req "gas_limit" z_encoding)
           (req "storage_limit" z_encoding)
           (req "failed" bool)
           (req "internal" bool)
           (req "op_level" int)
           (req "timestamp" string))

    let endorsement_encoding =
      def "endorsement"
        ~title:"Endorsement"
        ~description:"Tezos endorsement" @@
      conv
        (fun { endorse_src ; endorse_block_hash; endorse_block_level;
               endorse_slot; endorse_op_level; endorse_priority; endorse_timestamp }
          -> ("endorsement", endorse_block_hash, endorse_block_level,
              endorse_src, endorse_slot, endorse_op_level, endorse_priority,
              endorse_timestamp))
        (fun (_k,  endorse_block_hash, endorse_block_level, endorse_src,
              endorse_slot, endorse_op_level, endorse_priority, endorse_timestamp)
          -> { endorse_src; endorse_block_hash; endorse_block_level;
               endorse_slot; endorse_op_level; endorse_priority; endorse_timestamp })
        (obj8
           (req "kind" string)
           (req "block" string)
           (req "level" int)
           (* ocp field *)
           (req "endorser" account_name_encoding)
           (req "slots" (list int))
           (req "op_level" int)
           (req "priority" int)
           (req "timestamp" string))


    let proposal_encoding =
      def "proposal"
        ~title:"Proposal"
        ~description:"Tezos proposal" @@
      (obj3
         (req "kind" string)
         (req "period" int32)
         (req "proposals" (list string)))

    let ballot_encoding =
      def "ballot"
        ~title:"Ballot"
        ~description:"Tezos ballot" @@
      (obj4
         (req "kind" string)
         (req "period" int32)
         (req "proposal" string)
         (req "ballot" string))

    let seed_nonce_revelation_encoding =
      def "nonce_revelation"
        ~title:"Nonce Revelation"
        ~description:"Tezos seed nonce revelation" @@
      conv
         (fun { seed_level; seed_nonce } -> ("nonce", seed_level, seed_nonce))
         (fun (_k, seed_level, seed_nonce) -> { seed_level; seed_nonce } )
         (obj3
            (req "kind" string)
            (req "level" int)
            (req "nonce" string))

    let activation_encoding =
      def "activation"
        ~title:"Activation"
        ~description:"Tezos activation" @@
      conv
        (fun { act_pkh; act_secret; act_balance; act_op_level; act_timestamp }
          -> ("activation", act_pkh, act_secret, act_balance, act_op_level,
              act_timestamp))
        (fun (_, act_pkh, act_secret, act_balance, act_op_level, act_timestamp)
          -> { act_pkh ; act_secret; act_balance; act_op_level; act_timestamp })
        (obj6
           (req "kind" string)
           (req "pkh" account_name_encoding)
           (req "secret" string)
           (opt "balance" tez)
           (req "op_level" int)
           (req "timestamp" string))

    let double_baking_evidence_encoding =
      def "double_baking_evidence"
        ~title:"Double baking evidence"
        ~description:"Tezos double baking evidence" @@
      conv
        (fun {double_baking_header1; double_baking_header2;
              double_baking_main ; double_baking_accused ;
              double_baking_denouncer ; double_baking_lost_deposit ;
              double_baking_lost_rewards ; double_baking_lost_fees;
              double_baking_gain_rewards
             } ->
          ("double_baking_evidence", double_baking_header1, double_baking_header2,
           double_baking_main, double_baking_accused,
           double_baking_denouncer, double_baking_lost_deposit,
           double_baking_lost_rewards, double_baking_lost_fees,
           double_baking_gain_rewards))
        (fun (_k, double_baking_header1, double_baking_header2,
              double_baking_main, double_baking_accused,
              double_baking_denouncer, double_baking_lost_deposit,
              double_baking_lost_rewards, double_baking_lost_fees,
              double_baking_gain_rewards) ->
          {double_baking_header1; double_baking_header2; double_baking_main ;
           double_baking_accused ; double_baking_denouncer ;
           double_baking_lost_deposit ; double_baking_lost_rewards ;
           double_baking_lost_fees; double_baking_gain_rewards})
        (obj10
           (req "kind" string)
           (req "op1" (Tezos_encoding.Encoding.Block_header.encoding))
           (req "op2" (Tezos_encoding.Encoding.Block_header.encoding))
           (req "main" int)
           (req "offender" account_name_encoding)
           (req "denouncer" account_name_encoding)
           (req "lost_deposit" int64)
           (req "lost_rewards" int64)
           (req "lost_fees" int64)
           (req "gain_rewards" int64))

    let double_endorsement_evidence_encoding op_encoding =
      def "double_endorsement_evidence"
        ~title:"Double endorsement evidence"
        ~description:"Tezos double endorsement evidence" @@
      conv
        (fun {double_endorsement1; double_endorsement2} ->
           ("double_endorsement_evidence", double_endorsement1, double_endorsement2))
        (fun (_k, double_endorsement1, double_endorsement2) ->
           {double_endorsement1; double_endorsement2})
        (obj3
           (req "kind" string)
           (req "op1" op_encoding)
           (req "op2" op_encoding))

    let manager_encoding =
      def "manager_operation"
        ~title:"Manager operation"
        ~description:"Tezos manager operation" @@
      (obj3
         (req "kind" string)
         (req "source" account_name_encoding)
         (req "operations"
            (list (union [
                 case reveal_encoding
                   (function
                     | Reveal rvl -> Some rvl
                     | _ -> None)
                   (fun rvl -> Reveal rvl) ;
                 case transaction_encoding
                   (function
                     | Transaction tr -> Some tr
                     | _ -> None)
                   (fun tr -> Transaction tr) ;
                 case origination_encoding
                   (function
                     | Origination ori -> Some ori
                     | _ -> None)
                   (fun ori -> Origination ori) ;
                 case delegation_encoding
                   (function
                     | Delegation del -> Some del
                     | _ -> None)
                   (fun del -> Delegation del) ]))))

    let consensus_encoding = endorsement_encoding

    let amendment_encoding =
      def "amendment"
        ~title:"Amendment"
        ~description:"Tezos amendment" @@
      merge_objs
        (obj1 (req "source" account_name_encoding))
        (union [
            case proposal_encoding
              (function
                | Proposal {prop_voting_period ; prop_proposals } ->
                  Some ("Proposal", prop_voting_period, prop_proposals)
                | _ -> None)
              (fun (_k, prop_voting_period, prop_proposals) ->
                 Proposal { prop_voting_period ; prop_proposals }) ;
            case ballot_encoding
              (function
                | Ballot { ballot_voting_period ; ballot_proposal ; ballot_vote } ->
                  Some ("Ballot", ballot_voting_period, ballot_proposal, Tezos_utils.string_of_ballot_vote ballot_vote)
                | _ -> None)
              (fun (_k, ballot_voting_period,
                    ballot_proposal, ballot_vote) ->
                let ballot_vote = Tezos_utils.ballot_of_string ballot_vote in
                Ballot
                  {  ballot_voting_period ; ballot_proposal ; ballot_vote })
             ])

    let dictator_encoding =
      let activate_encoding =
         def "activate" ~title:"Activate" @@
        obj2
          (req "chain" string) (* needs to be "activate" *)
          (req "hash" string) in
      let activate_testnet_encoding =
        def "activate_testnet" ~title:"Activate Testnet" @@
        obj2
          (req "chain" string) (* needs to be "activate_testchain" *)
          (req "hash" string) in
      def "dictator_operation"
        ~title:"Dictator operation"
        ~description:"Tezos dictator operation" @@
      union [
        case activate_encoding
          (function _ -> None)
          (fun (_chain, _hash) -> Activate) ;
        case activate_testnet_encoding
          (function _ -> None)
          (fun (_chain, _hash) -> Activate)
      ]

    let signed_operation_encoding =
      def "signed_operation"
        ~title:"Signed operation"
        ~description:"Tezos signed operation" @@
      union [
        case consensus_encoding
          (function
            | Consensus Endorsement e -> Some e
            | _ -> None)
          (fun c -> Consensus (Endorsement c)) ;
        case manager_encoding
          (function
            | Manager m -> Some m
            | _ -> None)
          (fun m -> Manager m) ;
        case amendment_encoding
          (function
            | Amendment (source, am) -> Some (source, am)

            | _ -> None)
          (fun (source, am) -> Amendment (source, am)) ;
        case dictator_encoding
          (fun _ -> None)
          (fun d -> Dictator d)
      ]

    let unsigned_operation_encoding encoding =
      def "unsigned_operation"
        ~title:"Unsigned operation"
        ~description:"Tezos unsigned operation" @@
      obj1
        (req "operations"
           (list
              (union [
                  case seed_nonce_revelation_encoding
                    (function
                      | Seed_nonce_revelation s -> Some s
                      | _ -> None)
                    (fun s -> Seed_nonce_revelation s) ;
                  case (activation_encoding)
                    (function
                      | Activation a -> Some a
                      | _ -> None)
                    (fun act -> Activation act) ;
                  case (double_baking_evidence_encoding)
                    (function
                      | Double_baking_evidence dbe -> Some dbe
                      | _ -> None)
                    (fun evidence -> Double_baking_evidence evidence) ;
                  case (double_endorsement_evidence_encoding encoding)
                    (function
                      | Double_endorsement_evidence dee -> Some dee
                      | _ -> None)
                    (fun evidence -> Double_endorsement_evidence evidence)])))


    let proto_operation_encoding encoding =
      def "proto_operation"
        ~title:"Proto operation"
        ~description:"Tezos proto operation" @@
      union [
        case (unsigned_operation_encoding encoding)
          (function
            | Anonymous a -> Some a
            | _ -> None)
          (fun a -> Anonymous a) ;
        case signed_operation_encoding
          (function
            | Sourced s -> Some s
            | _ -> None)
          (fun s -> Sourced s)
      ]

    let operation_encoding =
      mu "mu_operation"
        (fun encoding ->
           proto_operation_encoding encoding)

    let signed_proto_operation_encoding =
      merge_objs
        operation_encoding
        (obj1 (opt "signature" string))

    let operation_type =
      (list (list
               (merge_objs
                  signed_proto_operation_encoding
                  (obj3
                     (req "hash" string)
                     (opt "net_id" string)
                     (req "branch" string)))))

    let parsed_op =
      array
        (merge_objs
           signed_proto_operation_encoding
           (obj1
              (req "branch" string)))
  end



  module Protocol = struct

    let encoding =
      def "protocol_hash"
        ~title:"Protocol"
        ~description:"Tezos protocol" @@
      (conv
         (fun { proto_name; proto_hash } -> ( proto_name, proto_hash ))
         (fun ( proto_name, proto_hash ) -> { proto_name; proto_hash } )
         (obj2
            (req "name" string)
            (req "hash" string)))
  end

  module BakeOp = struct

    let encoding =

      def "baked_block"
        ~title:"Baking"
        ~description:"Tezos baking" @@
      conv
        (fun {bk_block_hash; bk_baker_hash; bk_level; bk_cycle ; bk_priority ;
              bk_missed_priority; bk_distance_level; bk_fees; bk_bktime;
              bk_baked; bk_tsp}
          -> (bk_block_hash, bk_baker_hash, bk_level, bk_cycle, bk_priority,
              bk_missed_priority, bk_distance_level, bk_fees, bk_bktime,
              bk_baked, bk_tsp))
        (fun (bk_block_hash, bk_baker_hash, bk_level, bk_cycle, bk_priority,
              bk_missed_priority, bk_distance_level, bk_fees, bk_bktime,
              bk_baked, bk_tsp)
          -> {bk_block_hash; bk_baker_hash; bk_level; bk_cycle ; bk_priority;
              bk_missed_priority; bk_distance_level; bk_fees; bk_bktime;
              bk_baked; bk_tsp})
        (EzEncoding.obj11
           (req "block_hash" string)
           (req "baker_hash" account_name_encoding)
           (req "level" int)
           (req "cycle" int)
           (req "priority" int)
           (opt "missed_priority" int)
           (req "distance_level" int)
           (req "fees" tez)
           (req "bake_time" int)
           (req "baked" bool)
           (req "timestamp" string))
    let bakings = list encoding

  end

  module BakeEndorsementOp = struct

    let encoding =
      def "endorsed_block"
        ~title:"Endorsing"
        ~description:"Tezos endorsing" @@
      conv
        (fun {ebk_block; ebk_source; ebk_level; ebk_cycle; ebk_priority;
              ebk_dist; ebk_slots; ebk_lr_nslot; ebk_tsp}
          -> (ebk_block, ebk_source, ebk_level, ebk_cycle, ebk_priority,
              ebk_dist, ebk_slots, ebk_lr_nslot, ebk_tsp))
        (fun (ebk_block, ebk_source, ebk_level, ebk_cycle, ebk_priority,
              ebk_dist, ebk_slots, ebk_lr_nslot, ebk_tsp)
          -> {ebk_block; ebk_source; ebk_level; ebk_cycle; ebk_priority;
              ebk_dist; ebk_slots; ebk_lr_nslot; ebk_tsp})
        (obj9
           (opt "block" string)
           (opt "source" account_name_encoding)
           (req "level" int)
           (opt "cycle" int)
           (opt "priority" int)
           (opt "distance_level" int)
           (opt "slots" (list int))
           (req "lr_nslot" int)
           (opt "timestamp" string))
    let bakings = list encoding

  end

  module CycleBakeOp = struct

    let count_encoding =
      def "baking_count"
        ~title:"Baking count"
        ~description:"Different counter for baking" @@
      conv
        (fun {cnt_all; cnt_miss; cnt_steal} ->
           (cnt_all, cnt_miss, cnt_steal))
        (fun (cnt_all, cnt_miss, cnt_steal) ->
           {cnt_all; cnt_miss; cnt_steal})
        (obj3
           (req "count_all" int64)
           (req "count_miss" int64)
           (req "count_steal" int64))

    let tez_encoding =
      def "baking_money"
        ~title:"Baking Money"
        ~description:"Fees, rewards and deposits for baking" @@
      conv
        (fun {tez_fee; tez_reward; tez_deposit} -> (tez_fee, tez_reward, tez_deposit))
        (fun (tez_fee, tez_reward, tez_deposit) -> {tez_fee; tez_reward; tez_deposit})
        (obj3
           (req "fee" int64)
           (req "reward" int64)
           (req "deposit" int64))

    let encoding =
      def "cycle_baking"
        ~title:"Cycle Baking"
        ~description:"Summary of bakings for a cycle" @@
      conv
        (fun {cbk_cycle; cbk_depth; cbk_count; cbk_tez; cbk_priority; cbk_bktime}
          -> (cbk_cycle, cbk_depth, cbk_count, cbk_tez, cbk_priority, cbk_bktime))
        (fun (cbk_cycle, cbk_depth, cbk_count, cbk_tez, cbk_priority, cbk_bktime)
          -> {cbk_cycle; cbk_depth; cbk_count; cbk_tez; cbk_priority; cbk_bktime})
        (obj6
           (req "cycle" int)
           (req "depth" int)
           (req "count" count_encoding)
           (req "tez" tez_encoding)
           (opt "priority" float)
           (opt "bake_time" int))
    let bakings = list encoding

  end

  module CycleEndorsementOp = struct

    let encoding =
      def "cycle_endorsing"
        ~title:"Cycle Endorsing"
        ~description:"Summary of endorsings for a cycle" @@
      conv
        (fun {ced_cycle; ced_depth; ced_slots; ced_tez; ced_priority}
          -> (ced_cycle, ced_depth, ced_slots, ced_tez, ced_priority))
        (fun (ced_cycle, ced_depth, ced_slots, ced_tez, ced_priority)
          -> {ced_cycle; ced_depth; ced_slots; ced_tez; ced_priority})
        (obj5
           (req "cycle" int)
           (req "depth" int)
           (req "slots" CycleBakeOp.count_encoding)
           (req "tez" CycleBakeOp.tez_encoding)
           (req "priority" float))
    let bakings = list encoding

  end

  module Rights = struct

    let encoding =
      def "baking_endorsing_rights"
        ~title:"Baking/Endorsing Rights"
        ~description:"Baking and endorsing rights for a level" @@
      conv
        (fun ({ r_level; r_bakers; r_endorsers ; r_bakers_priority; r_baked})
          -> (r_level, r_bakers, r_endorsers, r_bakers_priority, r_baked))
        (fun (r_level, r_bakers, r_endorsers, r_bakers_priority, r_baked)
          -> ({ r_level; r_bakers; r_endorsers; r_bakers_priority; r_baked}))
        (obj5
           (req "level" int)
           (req "bakers" (list account_name_encoding))
           (req "endorsers" (list account_name_encoding))
           (req "bakers_priority" (list int))
           (opt "baked" (tup2 account_name_encoding int)))

    let rights = list encoding

  end

  module BakerRights = struct

    let encoding =
      def "baking_rights"
        ~title:"Baking Rights"
        ~description:"Baking rights for a level" @@
      conv
        (fun ({ br_level; br_cycle; br_priority; br_depth }) ->
           ( br_level, br_cycle, br_priority, br_depth ))
        (fun ( br_level, br_cycle, br_priority, br_depth ) ->
           ({ br_level; br_cycle; br_priority; br_depth }))
        (obj4
           (req "level" int)
           (req "cycle" int)
           (req "priority" int)
           (req "depth" int))

    let rights = list encoding

  end

  module EndorserRights = struct

    let encoding =
      def "endorsing_rights"
        ~title:"Endorsing Rights"
        ~description:"Endorsing rights for a level" @@
      conv
        (fun ({ er_level; er_cycle; er_nslot; er_depth }) ->
           ( er_level, er_cycle, er_nslot, er_depth ))
        (fun ( er_level, er_cycle, er_nslot, er_depth ) ->
           ({ er_level; er_cycle; er_nslot; er_depth }))
        (obj4
           (req "level" int)
           (req "cycle" int)
           (req "nslot" int)
           (req "depth" int))

    let rights = list encoding

  end

  module CycleRights = struct
    let encoding =
      def "cycle_rights"
        ~title:"Cycle Rights"
        ~description:"Summary of rights for a cycle" @@
      conv
        (fun { cr_cycle; cr_nblocks; cr_priority} ->
           ( cr_cycle, cr_nblocks, cr_priority ))
        (fun ( cr_cycle, cr_nblocks, cr_priority ) ->
           { cr_cycle; cr_nblocks; cr_priority})
        (obj3
           (req "cycle" int)
           (req "nblocks" int)
           (req "priority" float))

    let rights = list encoding
  end

  module Block = struct

    let operation_encoding =
      def "block_operation"
        ~title:"Block operation"
        ~description:"Operation in a block" @@
      obj3
        (req "hash" string)
        (req "branch" string)
        (req "data" string)

    let encoding =
      def "block"
        ~title:"Block"
        ~description:"Tezos block" @@
      conv
        (fun { hash; predecessor_hash; fitness; baker;
               timestamp; validation_pass; operations; protocol; nb_operations ;
               test_protocol; network; test_network;
               test_network_expiration; priority; level;
               commited_nonce_hash; pow_nonce; proto; data; signature;
               volume; fees; distance_level; cycle }
          ->
            let timestamp = Date.to_string timestamp in
            (hash, predecessor_hash, fitness,
             timestamp, validation_pass, [ operations ], protocol,
             test_protocol, network, test_network,
             test_network_expiration,
             baker, nb_operations, priority, level, commited_nonce_hash,
             pow_nonce, proto, data, signature, volume, fees, distance_level, cycle))
        (fun (hash, predecessor_hash, fitness,
              timestamp, validation_pass, operations, protocol,
              test_protocol, network, test_network,
              test_network_expiration,
              baker, nb_operations, priority, level, commited_nonce_hash,
              pow_nonce, proto, data, signature,
              volume, fees, distance_level, cycle)
          ->
            let timestamp = Date.from_string timestamp in
            { hash; predecessor_hash; fitness; baker ;
              nb_operations ;
              timestamp; validation_pass ;
              operations = List.flatten operations ; protocol;
              test_protocol; network; test_network;
              test_network_expiration; priority; level;
              commited_nonce_hash; pow_nonce; proto; data; signature;
              volume; fees; distance_level; cycle } )
        (EzEncoding.obj24
           (req "hash" string)
           (req "predecessor_hash" string)
           (req "fitness" string)
           (req "timestamp" string)
           (req "validation_pass" int)
           (req "operations" (list (list operation_encoding)))
           (req "protocol" Protocol.encoding)
           (req "test_protocol" Protocol.encoding)
           (req "network" string)
           (req "test_network" string)
           (req "test_network_expiration" string)
           (req "baker" account_name_encoding)
           (dft "nb_operations" int 0)
           (req "priority" int)
           (req "level" int)
           (req "commited_nonce_hash" string)
           (req "pow_nonce" string)
           (req "proto" int)
           (req "data" string)
           (req "signature" string)
           (req "volume" tez)
           (req "fees" tez)
           (req "distance_level" int)
           (req "cycle" int))

    let blocks = list encoding

  end

  module Nonce_hash = struct
    let encoding =
      def "nonces"
        ~title:"Nonces"
        ~description:"Nonces" @@
      let op =
        obj3
          (opt "operation_hash" string)
          (req "level" int)
          (req "block_hash" string) in
      obj2
        (req "cycle" int)
        (req "nonces" (list op))

  end

  module Level = struct
    let level_encoding =
      (obj7
         (req "level" int)
         (req "level_position" int)
         (req "cycle" int)
         (req "cycle_position" int)
         (req "voting_period" int)
         (req "voting_period_position" int)
         (req "expected_commitment" bool))


    let encoding =
      def "level"
        ~title:"Level"
        ~description:"Level detailed information" @@
      conv
        (fun { lvl_level; lvl_level_position;
               lvl_cycle; lvl_cycle_position;
               lvl_voting_period; lvl_voting_period_position }
          -> (lvl_level, lvl_level_position, lvl_cycle, lvl_cycle_position,
              lvl_voting_period, lvl_voting_period_position, false))
        (fun (lvl_level, lvl_level_position, lvl_cycle, lvl_cycle_position,
              lvl_voting_period, lvl_voting_period_position, _) ->
          { lvl_level; lvl_level_position;
            lvl_cycle; lvl_cycle_position;
            lvl_voting_period; lvl_voting_period_position } )
        level_encoding

  end

  module Health = struct
    let encoding =
      def "health"
        ~title:"Health"
        ~description:"Information about the health of the chain" @@
      conv
        (fun ({ cycle_start_level ; cycle_end_level ;
                cycle_volume ; cycle_fees ;
                cycle_bakers ; cycle_endorsers ;
                cycle_date_start ; cycle_date_end ;
                endorsements_rate ; main_endorsements_rate ;
                alt_endorsements_rate ; empty_endorsements_rate ;
                double_endorsements ; main_revelation_rate ;
                alternative_heads_number ; switch_number ;
                longest_switch_depth ; mean_priority ; score_priority ;
                biggest_block_volume ; biggest_block_fees ; top_baker})
          -> (cycle_start_level, cycle_end_level,
              cycle_volume, cycle_fees,
              cycle_bakers, cycle_endorsers,
              endorsements_rate, main_endorsements_rate,
              alt_endorsements_rate, empty_endorsements_rate,
              double_endorsements, main_revelation_rate,
              alternative_heads_number, switch_number,
              longest_switch_depth, mean_priority, score_priority,
              biggest_block_volume, biggest_block_fees, top_baker,
              cycle_date_start, cycle_date_end))
        (fun (cycle_start_level, cycle_end_level,
              cycle_volume, cycle_fees,
              cycle_bakers, cycle_endorsers,
              endorsements_rate, main_endorsements_rate,
              alt_endorsements_rate, empty_endorsements_rate,
              double_endorsements, main_revelation_rate,
              alternative_heads_number, switch_number,
              longest_switch_depth, mean_priority, score_priority,
              biggest_block_volume, biggest_block_fees, top_baker,
              cycle_date_start, cycle_date_end) ->
          { cycle_start_level ; cycle_end_level ; cycle_volume ; cycle_fees ;
            cycle_bakers ; cycle_endorsers ; cycle_date_start ; cycle_date_end ;
            endorsements_rate ;
            main_endorsements_rate ; alt_endorsements_rate ;
            empty_endorsements_rate ; double_endorsements ;
            main_revelation_rate ; alternative_heads_number ;
            switch_number ; longest_switch_depth ; mean_priority ;
            score_priority ; biggest_block_volume ;
            biggest_block_fees; top_baker })
        (EzEncoding.obj22
           (req "cycle_start_level" int)
           (req "cycle_end_level" int)
           (req "cycle_volume" tez)
           (req "cycle_fees" tez)
           (req "cycle_bakers" int)
           (req "cycle_endorsers" int)
           (req "endorsements_rate" float)
           (req "main_endorsements_rate" float)
           (req "alt_endorsements_rate" float)
           (req "empty_endorsements_rate" float)
           (req "double_endorsements" int)
           (req "main_revelation_rate" float)
           (req "alternative_heads_number" int)
           (req "switch_number" int)
           (req "longest_switch_depth" int)
           (req "mean_priority" float)
           (req "score_priority" float)
           (req "big_block_volume" (tup2 string int))
           (req "big_block_fees" (tup2 string int))
           (req "top_baker" account_name_encoding)
           (req "cycle_date_start" (tup3 int int int))
           (req "cycle_date_end" (tup3 int int int)))

  end

  module Charts = struct

    let per_day_encoding kind =
      conv (fun { pd_days; pd_value } -> (pd_days, pd_value))
        (fun ( pd_days, pd_value) -> { pd_days; pd_value })
        (obj2
           (req "days" (array string))
           (req "value" (array kind)))

    let int_per_day_encoding = per_day_encoding int
    let float_per_day_encoding = per_day_encoding float
    let int64_per_day_encoding = per_day_encoding int64

    let mini_stats =
      conv
        (fun { ms_period; ms_nhours; ms_nblocks; ms_nops; ms_volume; ms_fees } ->
           ( ms_period, ms_nhours, ms_nblocks, ms_nops, ms_volume, ms_fees ) )
        (fun ( ms_period, ms_nhours, ms_nblocks, ms_nops, ms_volume, ms_fees ) ->
           { ms_period; ms_nhours; ms_nblocks; ms_nops; ms_volume; ms_fees}
        )
        (obj6
           (req "period" (array string))
           (req "nhours" (array int))
           (req "nblocks" (array int))
           (req "nops" (array int))
           (req "volume" (array int64))
           (req "fees" (array int64))
        )

  end

  module Network = struct

    let point_to_string = function
      | None -> None
      | Some ((addr, port), timestamp) ->
        Some (Printf.sprintf "%s:%d" addr port, timestamp)

    let peer_to_string peer =
      match peer with
      | None -> ""
      | Some s-> s

    let to_peer point_id  = point_id

    let last_connection =
      function
      | None -> "", ""
      | Some (point, date) -> peer_to_string (Some point), date

    let encoding =
      let peer_encoding =
        def "peers"
          ~title:"Peer"
          ~description:"Information about peers" @@
        conv
          (fun (
             { peer_id; country; score ; trusted ; conn_metadata ;
               state ; id_point ; stat ;
               last_failed_connection ; last_rejected_connection ;
               last_established_connection ; last_disconnection ;
               last_seen ; last_miss })
             ->
               let point_id = peer_to_string id_point in
               let state =
                 match state with
                   Accepted -> "accepted" | Running -> "running" | Disconnected -> "disconnected" in
               let last_failed_connection_point, last_failed_connection_date =
                 last_connection last_failed_connection in
               let last_rejected_connection_point, last_rejected_connection_date =
                 last_connection last_rejected_connection in
               let last_established_connection_point, last_established_connection_date =
                 last_connection last_established_connection in
               let last_disconnection_point, last_disconnection_date =
                 last_connection last_disconnection in
               let last_seen_point, last_seen_date = last_connection last_seen in
               let last_miss_point, last_miss_date = last_connection last_miss in
               (peer_id, (fst country, snd country), point_id, trusted, conn_metadata,
                score, state,
                stat.total_sent, stat.total_recv, stat.current_inflow, stat.current_outflow,
                last_failed_connection_point, last_failed_connection_date,
                last_rejected_connection_point, last_rejected_connection_date,
                last_established_connection_point, last_established_connection_date,
                last_disconnection_point, last_disconnection_date,
                last_seen_point, last_seen_date, last_miss_point, last_miss_date))
          (fun (peer_id, (country_name, country_code), point_id, trusted, conn_metadata,
                score, state,
                total_sent, total_recv, current_inflow, current_outflow,
                last_failed_connection_point, last_failed_connection_date,
                last_rejected_connection_point, last_rejected_connection_date,
                last_established_connection_point, last_established_connection_date,
                last_disconnection_point, last_disconnection_date,
                last_seen_point, last_seen_date, last_miss_point, last_miss_date)
            ->
              let country = country_name, country_code in
              let state =
                match state with
                | "accepted" -> Accepted
                | "running"  -> Running
                | "disconnected" -> Disconnected
                | _ -> assert false in
               let id_point = Some (to_peer point_id) in
               let last_failed_connection =
                 Some (to_peer last_failed_connection_point, last_failed_connection_date) in
               let last_rejected_connection =
                 Some (to_peer last_rejected_connection_point, last_rejected_connection_date) in
               let last_established_connection =
                 Some (to_peer last_established_connection_point, last_established_connection_date) in
               let last_disconnection =
                 Some (to_peer last_disconnection_point, last_disconnection_date) in
               let last_seen = Some (to_peer last_seen_point, last_seen_date) in
               let last_miss = Some (to_peer last_miss_point, last_miss_date) in
               { peer_id; country; score ; trusted ; conn_metadata ;
                 state ; id_point ;
                 stat = { total_sent; total_recv; current_inflow; current_outflow } ;
                 last_failed_connection ; last_rejected_connection ;
                 last_established_connection ; last_disconnection ;
                 last_seen; last_miss } )
          (EzEncoding.obj23
             (req "peer_id" string)
             (req "country" (tup2 string string))
             (req "point_id" string)
             (req "trusted" bool)
             (opt "conn_metadata" Tezos_encoding.conn_metadata_encoding)
             (req "score" float)
             (req "state" string)
             (req "total_sent" int64)
             (req "total_recv" int64)
             (req "current_inflow" int)
             (req "current_outflow" int)
             (req "last_failed_connection_peer" string)
             (req "last_failed_connection_date" string)
             (req "last_rejected_connection_peer" string)
             (req "last_rejected_connection_date" string)
             (req "last_established_connection_peer" string)
             (req "last_established_connection_date" string)
             (req "last_disconnection_peer" string)
             (req "last_disconnection_date" string)
             (req "last_seen_peer" string)
             (req "last_seen_date" string)
             (req "last_miss_peer" string)
             (req "last_miss_date" string)) in
      (list peer_encoding)

    let country_stats_encoding =
      let encoding =
        def "country_stats"
          ~title:"Country Stats"
          ~description:"Information about country peers" @@
        conv
          (fun ({country_name; country_code; total})
            -> (country_name, country_code, total))
          (fun (country_name, country_code, total) ->
             {country_name; country_code; total})
          (obj3
             (req "country_name" string)
             (req "country_code" string)
             (req "total" int)) in
      (list encoding)
  end

  module MarketCap = struct
    let encoding =
      def "market_cap"
        ~title:"Market Cap"
        ~description:"Information about market cap for Tezos" @@
      conv
        (fun { mc_id; name; symbol; rank; price_usd; price_btc;
               volume_usd_24; market_cap_usd; available_supply;
               total_supply; max_supply; percent_change_1;
               percent_change_24; percent_change_7; last_updated }
          ->
            (mc_id, name, symbol, rank, price_usd, price_btc,
             volume_usd_24, market_cap_usd, available_supply,
             total_supply, max_supply, percent_change_1,
             percent_change_24, percent_change_7, last_updated))
        (fun (mc_id, name, symbol, rank, price_usd, price_btc,
              volume_usd_24, market_cap_usd, available_supply,
              total_supply, max_supply, percent_change_1,
              percent_change_24, percent_change_7, last_updated) ->
          { mc_id; name; symbol; rank; price_usd; price_btc;
            volume_usd_24; market_cap_usd; available_supply;
            total_supply; max_supply; percent_change_1;
            percent_change_24; percent_change_7; last_updated })
        (tup1
           (EzEncoding.obj15
              (req "id" string)
              (req "name" string)
              (req "symbol" string)
              (req "rank" string)
              (req "price_usd" string)
              (req "price_btc" string)
              (req "24h_volume_usd" (option string))
              (req "market_cap_usd" (option string))
              (req "available_supply" (option string))
              (req "total_supply" (option string))
              (req "max_supply" (option string))
              (req "percent_change_1h" (option string))
              (req "percent_change_24h" (option string))
              (req "percent_change_7d" (option string))
              (req "last_updated" string)))

  end

  module Account = struct
    let encoding =
      def "account"
        ~title:"Account"
        ~description:"Account information" @@
      conv
        (fun { account_hash; account_manager;
               account_spendable; account_delegatable}
          -> ((account_hash, account_manager,
               account_spendable, account_delegatable)))
        (fun ( account_hash, account_manager,
               account_spendable, account_delegatable)
          -> { account_hash; account_manager;
               account_spendable; account_delegatable} )
        (obj4
           (req "hash" account_name_encoding)
           (req "manager" account_name_encoding)
           (req "spendable" bool)
           (req "delegatable" bool))

    let accounts = list encoding
  end

  module Account_status = struct
    let encoding =
      def "account_status"
        ~title:"Account Status"
        ~description:"Status of an account" @@
      conv
        (fun { account_status_hash; account_status_revelation;
               account_status_origination;}
          -> ((account_status_hash, account_status_revelation,
               account_status_origination)))
        (fun ( account_status_hash, account_status_revelation,
               account_status_origination)
          -> { account_status_hash; account_status_revelation;
               account_status_origination;} )
        (obj3
           (req "hash" account_name_encoding)
           (opt "revelation" string)
           (opt "origination" string))
  end

  module Bonds_rewards = struct
    let priorities_encoding =
      (obj2
         (req "size" int)
         (req "priority" int))

    let encoding =
      def "frozen_balance"
        ~title:"Frozen Balance"
        ~description:"Detailed frozen balance" @@
      conv
        (fun { acc_b_rewards; acc_b_deposits; acc_fees;
               acc_e_rewards; acc_e_deposits }
          -> ( acc_b_rewards, acc_b_deposits, acc_fees,
               acc_e_rewards, acc_e_deposits ))
        (fun ( acc_b_rewards, acc_b_deposits, acc_fees,
               acc_e_rewards, acc_e_deposits )
          -> { acc_b_rewards; acc_b_deposits; acc_fees;
               acc_e_rewards; acc_e_deposits } )
        (obj5
           (req "block_rewards" tez)
           (req "block_deposits" tez)
           (req "block_acc_fees" tez)
           (req "endorsements_rewards" tez)
           (req "endorsement_deposits" tez))

    let extra =
      def "frozen_extras"
        ~title:"Frozen Extras"
        ~description:"Detailed frozen extras (denounciation, nonce revelation)" @@
      conv
        (fun { acc_dn_gain; acc_dn_deposit; acc_dn_rewards; acc_dn_fees;
               acc_rv_rewards; acc_rv_lost_rewards; acc_rv_lost_fees }
          -> ( acc_dn_gain, acc_dn_deposit, acc_dn_rewards, acc_dn_fees,
               acc_rv_rewards, acc_rv_lost_rewards, acc_rv_lost_fees ))
        (fun ( acc_dn_gain, acc_dn_deposit, acc_dn_rewards, acc_dn_fees,
               acc_rv_rewards, acc_rv_lost_rewards, acc_rv_lost_fees )
          -> { acc_dn_gain; acc_dn_deposit; acc_dn_rewards; acc_dn_fees;
               acc_rv_rewards; acc_rv_lost_rewards; acc_rv_lost_fees })
        (obj7
           (req "denouciation_gain" tez)
           (req "denounciation_deposits_loss" tez)
           (req "denouciation_rewards_loss" tez)
           (req "denounciation_fees_loss" tez)
           (req "revelation_rewards" tez)
           (req "revelation_rewards_loss" tez)
           (req "revelation_fees_loss" tez))
  end

  module Baker = struct
    type baker = BOk of string list | BError

    let encoding =
      def "baker"
        ~title:"Baker"
        ~description:"Baker summary" @@
      conv
        (fun ({ baker_hash; nb_blocks; volume_total; fees_total; nb_endorsements })
          -> (baker_hash, nb_blocks, volume_total, fees_total, nb_endorsements ))
        (fun (baker_hash, nb_blocks, volume_total, fees_total, nb_endorsements) ->
           { baker_hash; nb_blocks; volume_total; fees_total; nb_endorsements })
        (obj5
           (req "baker_hash" account_name_encoding)
           (req "nb_block" int)
           (req "volume_total" tez)
           (req "fees_total" tez)
           (req "nb_endorsements" int))

    let bakers_encoding = (list encoding)

  end

  module Operation = struct

    let encoding =
      conv
        (fun { op_hash; op_block_hash; op_network_hash; op_type }
          -> ( op_hash, op_block_hash, op_network_hash, op_type ))
        (fun ( op_hash, op_block_hash, op_network_hash, op_type ) ->
           { op_hash; op_block_hash; op_network_hash; op_type } )
        (obj4
           (req "hash" string)
           (req "block_hash" string)
           (req "network_hash" string)
           (req "type" Op.operation_encoding))

    let operation =
      def "operation"
        ~title:"Operation"
        ~description:"Operation information" encoding

    let operations = list operation

  end

  module Account_details = struct

    let node_encoding =
      obj7
        (req "manager" string)
        (req "balance" tez)
        (req "spendable" bool)
        (req "delegate"
           (obj2
              (req "setable" bool)
              (opt "value" string)))
        (opt "script" Micheline.script_encoding)
        (opt "storage" Micheline.script_expr_encoding)
        (req "counter" z_encoding)

    let encoding =
      def "account_details"
        ~title:"Account Details"
        ~description:"Detailled account information" @@
      conv
        (fun {acc_name; acc_manager; acc_balance; acc_spendable; acc_dlgt;
              acc_script; acc_storage; acc_counter; acc_node_timestamp }
          -> (acc_name, acc_manager, acc_balance, acc_spendable, acc_dlgt,
              acc_script, acc_storage, acc_counter, acc_node_timestamp))
        (fun (acc_name, acc_manager, acc_balance, acc_spendable, acc_dlgt,
              acc_script, acc_storage, acc_counter, acc_node_timestamp)
          -> {acc_name; acc_manager; acc_balance; acc_spendable; acc_dlgt;
              acc_script; acc_storage; acc_counter; acc_node_timestamp})
        (obj9
           (req "name" account_name_encoding)
           (req "manager" account_name_encoding)
           (req "balance" tez)
           (req "spendable" bool)
           (req "delegate" (obj2
                              (req "setable" bool)
                              (opt "value" account_name_encoding)))
           (opt "script" Micheline.script_encoding)
           (opt "storage" Micheline.script_expr_encoding)
           (req "counter" z_encoding)
           (opt "node_timestamp" string)
        )
  end

  module Supply = struct
    let h_encoding =
      def "supply_account"
        ~title:"Account supply information"
        ~description:"Information about the supply used by an account" @@
      conv
        (fun { h_activated_balance ; h_unfrozen_rewards ;
               h_revelation_rewards ; h_missing_revelations ;
               h_burned_tez_revelation ; h_burned_tez_origination ;
               h_tez_origination_recv ; h_tez_origination_send ;
               h_burned_tez_transaction ; h_tez_transaction_recv ;
               h_tez_transaction_send ; h_burned_tez_double_baking ;
               h_tez_dbe_rewards ; h_total } ->
          ( h_activated_balance, h_unfrozen_rewards,
            h_revelation_rewards, h_missing_revelations,
            h_burned_tez_revelation, h_burned_tez_origination,
            h_tez_origination_recv, h_tez_origination_send,
            h_burned_tez_transaction, h_tez_transaction_recv,
            h_tez_transaction_send, h_burned_tez_double_baking,
            h_tez_dbe_rewards, h_total ))
        (fun ( h_activated_balance, h_unfrozen_rewards,
               h_revelation_rewards, h_missing_revelations,
               h_burned_tez_revelation, h_burned_tez_origination,
               h_tez_origination_recv, h_tez_origination_send,
               h_burned_tez_transaction, h_tez_transaction_recv,
               h_tez_transaction_send, h_burned_tez_double_baking,
               h_tez_dbe_rewards, h_total ) ->
          { h_activated_balance ; h_unfrozen_rewards ;
            h_revelation_rewards ; h_missing_revelations ;
            h_burned_tez_revelation ; h_burned_tez_origination ;
            h_tez_origination_recv ; h_tez_origination_send ;
            h_burned_tez_transaction ; h_tez_transaction_recv ;
            h_tez_transaction_send ; h_burned_tez_double_baking ;
            h_tez_dbe_rewards ; h_total })
        (EzEncoding.obj14
           (req "h_activated_balance" int64)
           (req "h_unfrozen_rewards" int64)
           (req "h_revelation_rewards" int64)
           (req "h_missing_revelations" int)
           (req "h_burned_tez_revelation" int64)
           (req "h_burned_tez_origination" int64)
           (req "h_tez_origination_recv" int64)
           (req "h_tez_origination_send" int64)
           (req "h_burned_tez_transaction" int64)
           (req "h_tez_transaction_recv" int64)
           (req "h_tez_transaction_send" int64)
           (req "h_burned_tez_double_baking" int64)
           (req "h_tez_dbe_rewards" int64)
           (req "h_total" int64))

    let encoding =
      def "supply"
        ~title:"Supply"
        ~description:"Global supply information" @@
      conv
        (fun { dls ; foundation ; early_bakers ; contributors ;
               unfrozen_rewards ; missing_revelations ;
               revelation_rewards ; burned_tez_revelation ;
               burned_tez_origination ; burned_tez_double_baking ;
               total_supply_ico ; current_circulating_supply } ->
          ( dls, foundation, early_bakers, contributors,
            unfrozen_rewards, missing_revelations,
            revelation_rewards, burned_tez_revelation,
            burned_tez_origination, burned_tez_double_baking,
            total_supply_ico, current_circulating_supply ))
        (fun ( dls, foundation, early_bakers, contributors,
               unfrozen_rewards, missing_revelations,
               revelation_rewards, burned_tez_revelation,
               burned_tez_origination, burned_tez_double_baking,
               total_supply_ico, current_circulating_supply ) ->
          { dls ; foundation ; early_bakers ; contributors
          ; unfrozen_rewards ; missing_revelations ;
            revelation_rewards ; burned_tez_revelation ;
            burned_tez_origination ; burned_tez_double_baking ;
            total_supply_ico ; current_circulating_supply })
        (EzEncoding.obj12
           (req "dls" int64)
           (req "foundation" int64)
           (req "early_bakers" int64)
           (req "contributors" int64)
           (req "unfrozen_rewards" int64)
           (req "missing_revelation" int)
           (req "revelation_rewards" int64)
           (req "burned_tez_revelation" int64)
           (req "burned_tez_origination" int64)
           (req "burned_tez_double_baking" int64)
           (req "total_supply_ico" int64)
           (req "circulating_supply" int64))
  end

  module Rolls_distribution = struct
    let encoding = def "rolls" @@list (tup2 account_name_encoding int)
  end

  module Rewards_split = struct
    let encoding =
      def "delegate_rewards"
        ~title:"Delegate Rewards"
        ~description:"Information about delegate rewards" @@
      conv
        (fun { rs_delegate_staking_balance ; rs_delegators_nb ;
               rs_delegators_balance ; rs_block_rewards ;
               rs_endorsement_rewards ; rs_fees ;
               rs_baking_rights_rewards ; rs_endorsing_rights_rewards ;
               rs_gain_from_denounciation ; rs_lost_deposit ;
               rs_lost_rewards ; rs_lost_fees;
               rs_rv_rewards; rs_rv_lost_rewards; rs_rv_lost_fees } ->
          ( rs_delegate_staking_balance, rs_delegators_nb,
            rs_delegators_balance, rs_block_rewards,
            rs_endorsement_rewards, rs_fees, rs_baking_rights_rewards,
            rs_endorsing_rights_rewards,
            rs_gain_from_denounciation, rs_lost_deposit,
            rs_lost_rewards, rs_lost_fees,
            rs_rv_rewards, rs_rv_lost_rewards, rs_rv_lost_fees))
        (fun ( rs_delegate_staking_balance, rs_delegators_nb,
               rs_delegators_balance, rs_block_rewards,
               rs_endorsement_rewards, rs_fees, rs_baking_rights_rewards,
               rs_endorsing_rights_rewards,
               rs_gain_from_denounciation, rs_lost_deposit,
               rs_lost_rewards, rs_lost_fees,
               rs_rv_rewards, rs_rv_lost_rewards, rs_rv_lost_fees) ->
          { rs_delegate_staking_balance ; rs_delegators_nb ;
            rs_delegators_balance ; rs_block_rewards ;
            rs_endorsement_rewards ; rs_fees ;
            rs_baking_rights_rewards ; rs_endorsing_rights_rewards ;
            rs_gain_from_denounciation ; rs_lost_deposit ;
            rs_lost_rewards ; rs_lost_fees;
            rs_rv_rewards; rs_rv_lost_rewards; rs_rv_lost_fees})
        (EzEncoding.obj15
           (req "delegate_staking_balance" int64)
           (req "delegators_nb" int)
           (req "delegators_balance"
              (list (tup2 account_name_encoding int64)))
           (req "blocks_rewards" int64)
           (req "endorsements_rewards" int64)
           (req "fees" int64)
           (req "future_blocks_rewards" int64)
           (req "future_endorsements_rewards" int64)
           (req "gain_from_denounciation" int64)
           (req "lost_deposit_from_denounciation" int64)
           (req "lost_rewards_denounciation" int64)
           (req "lost_fees_denounciation" int64)
           (req "revelation_rewards" tez)
           (req "lost_revelation_rewards" tez)
           (req "lost_revelation_fees" tez))

    let status_encoding =
      def "reward_status"
        ~title:"Reward Status"
        ~description:"Reward status" @@
      conv
        (function
          | Cycle_in_progress -> "cycle_in_progress"
          | Cycle_pending -> "cycle_pending"
          | Rewards_pending -> "rewards_pending"
          | Rewards_delivered -> "rewards_delivered")
        (function
          | "cycle_in_progress" -> Cycle_in_progress
          | "cycle_pending" -> Cycle_pending
          | "rewards_pending" -> Rewards_pending
          | "rewards_delivered" -> Rewards_delivered
          | _ -> assert false)
        (obj1
           (req "status" string))

    let all_encoding =
      def "cycle_delegate_rewards"
        ~title:"Cycle Delegate Rewards"
        ~description:"Summary of delegate rewards for a cycle" @@
      conv
        (fun { ars_cycle ; ars_delegate_staking_balance ;
               ars_delegators_nb ; ars_delegate_delegated_balance ;
               ars_block_rewards ;
               ars_endorsement_rewards ; ars_fees ;
               ars_baking_rights_rewards ; ars_endorsing_rights_rewards ;
               ars_status ; ars_gain_from_denounciation ;
               ars_lost_deposit ; ars_lost_rewards ; ars_lost_fees;
               ars_rv_rewards; ars_rv_lost_rewards; ars_rv_lost_fees } ->
          ( ars_cycle, ars_delegate_staking_balance,
            ars_delegators_nb, ars_delegate_delegated_balance,
            ars_block_rewards,
            ars_endorsement_rewards, ars_fees,
            ars_baking_rights_rewards, ars_endorsing_rights_rewards,
            ars_status,
            ars_gain_from_denounciation,
            ars_lost_deposit, ars_lost_rewards, ars_lost_fees,
            ars_rv_rewards, ars_rv_lost_rewards, ars_rv_lost_fees))
        (fun ( ars_cycle, ars_delegate_staking_balance,
               ars_delegators_nb, ars_delegate_delegated_balance,
               ars_block_rewards,
               ars_endorsement_rewards, ars_fees,
               ars_baking_rights_rewards, ars_endorsing_rights_rewards,
               ars_status,
               ars_gain_from_denounciation,
               ars_lost_deposit, ars_lost_rewards, ars_lost_fees,
               ars_rv_rewards, ars_rv_lost_rewards, ars_rv_lost_fees) ->
          { ars_cycle ; ars_delegate_staking_balance;
            ars_delegators_nb ; ars_delegate_delegated_balance ;
            ars_block_rewards ;
            ars_endorsement_rewards ; ars_fees ;
            ars_baking_rights_rewards ; ars_endorsing_rights_rewards ;
            ars_status ; ars_gain_from_denounciation ;
            ars_lost_deposit ; ars_lost_rewards ; ars_lost_fees;
            ars_rv_rewards; ars_rv_lost_rewards; ars_rv_lost_fees})
        (EzEncoding.obj17
           (req "cycle" int)
           (req "delegate_staking_balance" int64)
           (req "delegators_nb" int)
           (req "delegated_balance" int64)
           (req "blocks_rewards" int64)
           (req "endorsements_rewards" int64)
           (req "fees" int64)
           (req "future_baking_rewards" int64)
           (req "future_endorsing_rewards" int64)
           (req "status" status_encoding)
           (req "gain_from_denounciation" int64)
           (req "lost_deposit_from_denounciation" int64)
           (req "lost_rewards_denounciation" int64)
           (req "lost_fees_denounciation" int64)
           (req "revelation_rewards" tez)
           (req "lost_revelation_rewards" tez)
           (req "lost_revelation_fees" tez)
           )

    let delegator_encoding =
      def "delegator_rewards"
        ~title:"Delegator Rewards"
        ~description:"Delegator rewards for a cycle" @@
      conv
        (fun {dor_cycle; dor_delegate; dor_staking_balance; dor_balance;
              dor_rewards; dor_extra_rewards; dor_losses; dor_status}
          -> (dor_cycle, dor_delegate, dor_staking_balance, dor_balance,
              dor_rewards, dor_extra_rewards, dor_losses, dor_status))
        (fun (dor_cycle, dor_delegate, dor_staking_balance, dor_balance,
              dor_rewards, dor_extra_rewards, dor_losses, dor_status)
          -> {dor_cycle; dor_delegate; dor_staking_balance; dor_balance;
              dor_rewards; dor_extra_rewards; dor_losses; dor_status})
        (obj8
           (req "cycle" int)
           (req "delegate" account_name_encoding)
           (req "staking_balance" int64)
           (req "balance" int64)
           (req "rewards" int64)
           (req "extra_rewards" int64)
           (req "losses" int64)
           (req "status" status_encoding))
    let delegator_encodings = list delegator_encoding

    let delegator_rewards_details =
      def "delegator_rewards_details"
        ~title:"Delegator Rewards Details"
        ~description:"Delegator rewards details for a cycle" @@
      conv
        (fun {dor_block_rewards; dor_end_rewards; dor_fees; dor_rv_rewards;
              dor_dn_gain; dor_rv_lost_rewards; dor_rv_lost_fees;
              dor_dn_lost_deposit; dor_dn_lost_rewards; dor_dn_lost_fees}
          -> (dor_block_rewards, dor_end_rewards, dor_fees, dor_rv_rewards,
              dor_dn_gain, dor_rv_lost_rewards, dor_rv_lost_fees,
              dor_dn_lost_deposit, dor_dn_lost_rewards, dor_dn_lost_fees))
        (fun (dor_block_rewards, dor_end_rewards, dor_fees, dor_rv_rewards,
              dor_dn_gain, dor_rv_lost_rewards, dor_rv_lost_fees,
              dor_dn_lost_deposit, dor_dn_lost_rewards, dor_dn_lost_fees)
          -> {dor_block_rewards; dor_end_rewards; dor_fees; dor_rv_rewards;
              dor_dn_gain; dor_rv_lost_rewards; dor_rv_lost_fees;
              dor_dn_lost_deposit; dor_dn_lost_rewards; dor_dn_lost_fees})
        (obj10
           (req "block_rewards" tez)
           (req "endorsement_rewards" tez)
           (req "fees" tez)
           (req "revelation_rewards" tez)
           (req "denounciation_gain" tez)
           (req "revelation_lost_rewards" tez)
           (req "revelation_lost_fees" tez)
           (req "denounciation_lost_deposit" tez)
           (req "denounciation_lost_rewards" tez)
           (req "denounciation_lost_fees" tez))

    let delegator_rewards_all =
      def "delegator_rewards_all"
        ~title:"Delegator Rewards All"
        ~description:"Delegator rewards with details included for a cycle" @@
      (merge_objs delegator_encoding delegator_rewards_details)
  end

  module Snapshot = struct
    let snapshot_encoding =
      def "snapshot"
        ~title:"Snapshot"
        ~description:"Snapshot information" @@
      conv
        (fun { snap_cycle ; snap_index ; snap_level ; snap_rolls } ->
           ( snap_cycle, snap_index, snap_level, snap_rolls ))
        (fun ( snap_cycle, snap_index, snap_level, snap_rolls ) ->
           { snap_cycle ; snap_index ; snap_level ; snap_rolls })
        (obj4
           (req "snapshot_cycle" int)
           (req "snapshot_index" int)
           (req "snapshot_level" int)
           (req "snapshot_rolls" int))

    let encoding = list snapshot_encoding
  end

  module Proto_details = struct
    let proto_encoding =
      def "protocol"
        ~title:"Protocol"
        ~description:"Protocol details" @@
      conv
        (fun {prt_index; prt_hash; prt_name; prt_start; prt_end}
          -> (prt_index, prt_hash, prt_name, prt_start, prt_end))
        (fun (prt_index, prt_hash, prt_name, prt_start, prt_end)
          -> {prt_index; prt_hash; prt_name; prt_start; prt_end})
        (obj5
           (req "protocol_index" int)
           (req "protocol_hash" string)
           (req "protocol_name" string)
           (req "block_start" int)
           (req "block_end" int))
    let encoding = list proto_encoding
  end

  module Date_enc = struct
    let encoding =
      conv
        (fun d -> Date.to_string d)
        (fun (d: string) -> Date.from_string d)
        (obj1
           (req "date" string))
  end

  module Balance_update_info = struct
    let bu_encoding =
      def "balance_update"
        ~title:"Balance Update"
        ~description:"Balance update information" @@
      conv
        (fun {bu_account; bu_block_hash; bu_diff; bu_date; bu_update_type;
              bu_op_type; bu_internal; bu_frozen; bu_level; bu_burn}
         -> (bu_account, bu_block_hash, bu_diff, bu_date, bu_update_type,
             bu_op_type, bu_internal, bu_frozen, bu_level, bu_burn))
        (fun (bu_account, bu_block_hash, bu_diff, bu_date, bu_update_type,
             bu_op_type, bu_internal, bu_frozen, bu_level, bu_burn)
         ->  {bu_account; bu_block_hash; bu_diff; bu_date; bu_update_type;
              bu_op_type; bu_internal; bu_frozen; bu_level; bu_burn})
        (obj10
           (req "account" string)
           (req "block" string)
           (req "diff" int64)
           (req "date" Date_enc.encoding)
           (req "update_type" string)
           (req "op_type" string)
           (req "internal" bool)
           (req "frozen" bool)
           (req "level" int32)
           (req "burn" bool))
    let encoding = list bu_encoding
  end

  module Balance = struct
    let encoding =
      def "balance"
        ~title:"Balance"
        ~description:"Balance details" @@
      conv
        (fun {b_spendable; b_frozen; b_rewards; b_fees; b_deposits} ->
          (b_spendable, b_frozen, b_rewards, b_fees, b_deposits) )
        (fun (b_spendable, b_frozen, b_rewards, b_fees, b_deposits) ->
          {b_spendable; b_frozen; b_rewards; b_fees; b_deposits})
        (obj5
           (req "spendable" int64)
           (req "frozen" int64)
           (req "rewards" int64)
           (req "fees" int64)
           (req "deposits" int64))
  end

  module H24_stats = struct
    let encoding =
      def "24h_stats"
        ~title:"24h Stats"
        ~description:"Statistics on the last 24h" @@
      conv
        (fun { h24_end_rate ; h24_block_0_rate ;
               h24_transactions ; h24_originations ;
               h24_delegations ; h24_activations ;
               h24_baking_rate ; h24_active_baker } ->
          ( h24_end_rate, h24_block_0_rate,
            h24_transactions, h24_originations,
            h24_delegations, h24_activations,
            h24_baking_rate, h24_active_baker))
        (fun ( h24_end_rate, h24_block_0_rate,
               h24_transactions, h24_originations,
               h24_delegations, h24_activations,
               h24_baking_rate, h24_active_baker ) ->
          { h24_end_rate ; h24_block_0_rate ;
            h24_transactions ; h24_originations ;
            h24_delegations ; h24_activations ;
            h24_baking_rate ; h24_active_baker})
        (obj8
           (req "h24_endorsements_rate" float)
           (req "h24_block_0_rate" float)
           (req "h24_transactions" int)
           (req "h24_originations" int)
           (req "h24_delegations" int)
           (req "h24_activations" int)
           (req "h24_baking_rate" float)
           (req "h24_active_baker" int))
  end

  module Server = struct

    let versions =
      def "server"
        ~title:"Server"
        ~description:"Server information" @@
      conv
        (fun { server_version; server_build; server_commit } ->
           ( server_version, server_build, server_commit ) )
        (fun ( server_version, server_build, server_commit ) ->
           { server_version; server_build; server_commit } )
        (obj3
           (req "version" string)
           (req "build" string)
           (req "commit" string))


    let ico_constants =
      def "ico_constants"
        ~title:"ICO Constants"
        ~description:"ICO constants" @@
      conv
        (fun
          {
            ico_company_tokens ;
            ico_foundation_tokens ;
            ico_early_tokens ;
            ico_contributors_tokens ;
            ico_wallets
          }
          ->
            (
              ico_company_tokens ,
              ico_foundation_tokens ,
              ico_early_tokens ,
              ico_contributors_tokens ,
              ico_wallets
            )
        )
        (fun
            (
              ico_company_tokens ,
              ico_foundation_tokens ,
              ico_early_tokens ,
              ico_contributors_tokens ,
              ico_wallets
            )
          ->
          {
            ico_company_tokens ;
            ico_foundation_tokens ;
            ico_early_tokens ;
            ico_contributors_tokens ;
            ico_wallets
          }
        )
        (obj5
           (dft "company_tokens" int64 0L)
           (req "foundation_tokens" int64)
           (dft "early_tokens" int64 0L)
           (dft "contributors_tokens" int64 0L)
           (dft "wallets" int 0)
        )

    let api_server_config =
      def "configuration_constants"
        ~title:"Configuration Constants"
        ~description:"Constants and information about configuration" @@
      conv
        (fun
          {
            conf_network ;
            conf_constants ;
            conf_ico ;
            conf_has_delegation ;
            conf_has_marketcap
          }
          ->
            (
              conf_network ,
              conf_constants ,
              conf_ico ,
              conf_has_delegation ,
              conf_has_marketcap
            )
        )
        (fun
          (
            conf_network ,
            conf_constants ,
            conf_ico ,
            conf_has_delegation ,
            conf_has_marketcap
          )
          ->
            {
              conf_network ;
              conf_constants;
              conf_ico ;
              conf_has_delegation ;
              conf_has_marketcap
            }
        )
        (obj5
           (req "network" string)
           (dft "constants" (list (tup2 int Tezos_encoding.constants)) [])
           (req "ico" ico_constants)
           (dft "has_delegation" bool false)
           (dft "has_marketcap" bool false)
        )

    let api_server_info =
      conv
        (fun
          {
            api_config ;
            api_date ;
            api_versions
          }
          ->
            (
              api_config ,
              api_date ,
              api_versions
            )
        )
        (fun
          (
            api_config ,
            api_date ,
            api_versions
          )
          ->
            {
              api_config ;
              api_date ;
              api_versions
          }
        )
        (obj3
           (req "config" api_server_config)
           (req "date" float)
           (req "versions" versions)
        )

  end

  module Voting_period_status_repr = struct
    let status_encoding =
      union  [
        case
          (constant "voting_period_passed")
          (function VPS_passed -> Some () | _ -> None)
          (fun () -> VPS_passed) ;
        case
          (constant "voting_period_waiting")
          (function VPS_wait -> Some () | _ -> None)
          (fun () -> VPS_wait) ;
        case
          (constant "voting_period_current")
          (function VPS_current -> Some () | _ -> None)
          (fun () -> VPS_current) ;
        case
          (constant "voting_period_ignored")
          (function VPS_ignored -> Some () | _ -> None)
          (fun () -> VPS_ignored) ;
      ]
  end

  module Voting_period_info = struct
    let prop_empty_encoding =
      obj1
        (req "proposal" (constant "empty"))
    let prop_encoding =
      obj3
        (req "proposal_hash" string)
        (req "nb_prop" int)
        (req "pc_winning_prop" float)
    let test_vote_encoding =
      obj3
        (req "test_voter_turnout" float)
        (req "test_quorum" float)
        (req "test_current_smajority" float)
    let testing_encoding = empty
    let promo_encoding =
      obj3
        (req "promo_voter_turnout" float)
        (req "promo_quorum" float)
        (req "promo_current_smajority" float)

    let encoding =
      union  [
        case prop_empty_encoding
          (function Sum_proposal_empty -> Some () | _ -> None)
          (fun () -> Sum_proposal_empty) ;
        case prop_encoding
          (function Sum_proposal (hash, prop, pc) -> Some (hash, prop, pc) | _ -> None)
          (fun (hash, prop, pc) -> Sum_proposal (hash, prop, pc)) ;
        case test_vote_encoding
          (function
            | Sum_testing_vote (actual_q, expected_q, smajor) ->
              Some (actual_q, expected_q, smajor)
            | _ -> None)
          (fun (actual_q, expected_q, smajor) ->
             Sum_testing_vote (actual_q, expected_q, smajor)) ;
        case testing_encoding
          (function Sum_testing -> Some () | _ -> None)
          (fun () -> Sum_testing) ;
        case promo_encoding
          (function
            | Sum_promo (actual_q, expteced_q, smajor) ->
              Some (actual_q, expteced_q, smajor)
            | _ -> None)
          (fun (actual_q, expteced_q, smajor) ->
             Sum_promo (actual_q, expteced_q, smajor) ) ;
      ]
  end

  module Proposal = struct

    let encoding =
      def "proposal"
        ~title:"Proposal"
        ~description:"Proposal with (up)votes" @@
      conv
        (fun {prop_period; prop_period_kind; prop_hash; prop_count; prop_votes;
              prop_source; prop_op; prop_ballot}
          -> let prop_ballot = Misc.convopt Tezos_utils.string_of_ballot_vote prop_ballot in
            (prop_period, prop_period_kind, prop_hash, prop_count, prop_votes,
             prop_source, prop_op, prop_ballot))
        (fun (prop_period, prop_period_kind, prop_hash, prop_count, prop_votes,
              prop_source, prop_op, prop_ballot)
          -> let prop_ballot = Misc.convopt Tezos_utils.ballot_of_string prop_ballot in
            {prop_period; prop_period_kind; prop_hash; prop_count; prop_votes;
             prop_source; prop_op; prop_ballot})
        (obj8
           (req "voting_period" int)
           (req "period_kind" Tezos_encoding.Encoding.Voting_period_repr.kind_encoding)
           (req "proposal_hash" string)
           (req "count" int)
           (req "votes" int)
           (req "source" account_name_encoding)
           (opt "operation" string)
           (opt "ballot" string)
        )

    let encodings = list encoding

    let voting_info =
      obj7
        (req "period" int)
        (req "kind" Tezos_encoding.Encoding.Voting_period_repr.kind_encoding)
        (req "cycle" int)
        (req "level" int)
        (req "max_period" bool)
        (req "period_status" (list Voting_period_status_repr.status_encoding))
        (req "quorum" int)

    let ballot_encoding =
      obj7
        (req "proposal" string)
        (req "nb_yay" int)
        (req "nb_nay" int)
        (req "nb_pass" int)
        (req "vote_yay" int)
        (req "vote_nay" int)
        (req "vote_pass" int)

    let vote_graphs_encoding =
      let graph = list (obj3 (req "period" int) (req "count" int) (req "rolls" int)) in
      obj2
        (req "proposals" graph)
        (req "ballots" graph)

    let summary_period =
      conv
        (fun { sum_period ; sum_cycle ; sum_level ; sum_period_info } ->
           (sum_period, sum_cycle, sum_level, sum_period_info))
        (fun (sum_period, sum_cycle, sum_level, sum_period_info) ->
           { sum_period ; sum_cycle ; sum_level ; sum_period_info })
        (obj4
           (req "period" int)
           (req "cycle" int)
           (req "level" int)
           (req "period_info" Voting_period_info.encoding))

  end

end

module Context_stats = struct

  let context_with_diff_encoding =
    def "context"
      ~title:"Context"
      ~description:"Context information" @@
    conv
      (fun
        { context_level ;
          context_addresses ; context_addresses_diff ;
          context_keys ; context_keys_diff ; context_revealed ;
          context_revealed_diff ; context_originated ; context_originated_diff ;
          context_contracts ; context_contracts_diff ; context_roll_owners ;
          context_roll_owners_diff ; context_rolls ; context_rolls_diff ;
          context_delegated ; context_delegated_diff ; context_delegators ;
          context_delegators_diff ; context_deleguees ; context_deleguees_diff ;
          context_self_delegates ; context_self_delegates_diff ;
          context_multi_deleguees ; context_multi_deleguees_diff ;
          context_current_balances ; context_current_balances_diff ;
          context_full_balances ; context_full_balances_diff ;
          context_staking_balances ; context_staking_balances_diff ;
          context_frozen_balances ; context_frozen_balances_diff ;
          context_frozen_deposits ; context_frozen_deposits_diff ;
          context_frozen_rewards ; context_frozen_rewards_diff ;
          context_frozen_fees ; context_frozen_fees_diff ; context_paid_bytes ;
          context_paid_bytes_diff ; context_used_bytes ;
          context_used_bytes_diff } ->
        (( context_level,
           context_addresses, context_addresses_diff,
           context_keys, context_keys_diff, context_revealed,
           context_revealed_diff, context_originated,
           context_originated_diff,
           context_contracts, context_contracts_diff, context_roll_owners,
           context_roll_owners_diff, context_rolls, context_rolls_diff,
           context_delegated, context_delegated_diff, context_delegators,
           context_delegators_diff, context_deleguees, context_deleguees_diff,
           context_self_delegates, context_self_delegates_diff,
           context_multi_deleguees),
         (context_multi_deleguees_diff,
          context_current_balances, context_current_balances_diff,
          context_full_balances, context_full_balances_diff,
          context_staking_balances, context_staking_balances_diff,
          context_frozen_balances, context_frozen_balances_diff,
          context_frozen_deposits, context_frozen_deposits_diff,
          context_frozen_rewards, context_frozen_rewards_diff,
          context_frozen_fees,
          context_frozen_fees_diff, context_paid_bytes,
          context_paid_bytes_diff, context_used_bytes,
          context_used_bytes_diff)))
      (fun
        (( context_level,
           context_addresses, context_addresses_diff,
           context_keys, context_keys_diff, context_revealed,
           context_revealed_diff, context_originated, context_originated_diff,
           context_contracts, context_contracts_diff, context_roll_owners,
           context_roll_owners_diff, context_rolls, context_rolls_diff,
           context_delegated, context_delegated_diff, context_delegators,
           context_delegators_diff, context_deleguees, context_deleguees_diff,
           context_self_delegates, context_self_delegates_diff,
           context_multi_deleguees),
         ( context_multi_deleguees_diff,
           context_current_balances, context_current_balances_diff,
           context_full_balances, context_full_balances_diff,
           context_staking_balances, context_staking_balances_diff,
           context_frozen_balances, context_frozen_balances_diff,
           context_frozen_deposits, context_frozen_deposits_diff,
           context_frozen_rewards, context_frozen_rewards_diff,
           context_frozen_fees,
           context_frozen_fees_diff, context_paid_bytes,
           context_paid_bytes_diff, context_used_bytes,
           context_used_bytes_diff) ) ->
        { context_level ;
          context_addresses ; context_addresses_diff ;
          context_keys ; context_keys_diff ; context_revealed ;
          context_revealed_diff ; context_originated ; context_originated_diff ;
          context_contracts ; context_contracts_diff ; context_roll_owners ;
          context_roll_owners_diff ; context_rolls ; context_rolls_diff ;
          context_delegated ; context_delegated_diff ; context_delegators ;
          context_delegators_diff ; context_deleguees ; context_deleguees_diff ;
          context_self_delegates ; context_self_delegates_diff ;
          context_multi_deleguees ; context_multi_deleguees_diff ;
          context_current_balances ; context_current_balances_diff ;
          context_full_balances ; context_full_balances_diff ;
          context_staking_balances ; context_staking_balances_diff ;
          context_frozen_balances ; context_frozen_balances_diff ;
          context_frozen_deposits ; context_frozen_deposits_diff ;
          context_frozen_rewards ; context_frozen_rewards_diff ;
          context_frozen_fees ; context_frozen_fees_diff ; context_paid_bytes ;
          context_paid_bytes_diff ; context_used_bytes ;
          context_used_bytes_diff })
      (merge_objs
         (EzEncoding.obj24
            (opt "level" V1.Level.encoding )
            (req "addresses"  int )
            (req "addresses_diff" float )
            (req "keys"  int  )
            (req "keys_diff" float )
            (req "revealed"  int  )
            (req "revealed_diff" float )
            (req "originated"  int  )
            (req "originated_diff" float )
            (req "contracts"  int  )
            (req "contracts_diff" float )
            (req "roll_owners"  int  )
            (req "roll_owners_diff" float )
            (req "rolls"  int  )
            (req "rolls_diff" float )
            (req "delegated"  int64  )
            (req "delegated_diff" float )
            (req "delegators"  int  )
            (req "delegators_diff" float )
            (req "deleguees"  int  )
            (req "deleguees_diff" float )
            (req "self_delegates"  int  )
            (req "self_delegates_diff" float )
            (req "multi_deleguees"  int  ))
         (EzEncoding.obj19
            (req "multi_deleguees_diff" float )
            (req "current_balances" int64)
            (req "current_balances_diff" float )
            (req "full_balances" int64)
            (req "full_balances_diff" float )
            (req "staking_balances"  int64  )
            (req "staking_balances_diff" float )
            (req "frozen_balances"  int64  )
            (req "frozen_balances_diff" float )
            (req "frozen_deposits"  int64  )
            (req "frozen_deposits_diff" float )
            (req "frozen_rewards"  int64  )
            (req "frozen_rewards_diff" float )
            (req "frozen_fees"  int64  )
            (req "frozen_fees_diff" float )
            (req "paid_bytes"  int64  )
            (req "paid_bytes_diff" float )
            (req "used_bytes"  int64  )
            (req "used_bytes_diff" float )))

end

module Tops = struct

  let context_top_accounts_encoding =
    def "tops"
      ~title:"Context Top Accounts"
      ~description:"Top accounts from the context" @@
    conv
      (fun
        { context_top_period ; context_top_kind ;
          context_top_hash ; context_top_list }
        ->
          ( context_top_period , context_top_kind ,
            context_top_hash , context_top_list )
      )
      (fun
        ( context_top_period , context_top_kind ,
          context_top_hash , context_top_list )
        ->
          { context_top_period ; context_top_kind ; context_top_hash ; context_top_list }
      )
      (obj4
         (req "period" string)
         (req "kind" string)
         (req "block" string)
         (req "list" (list (tup2 string int64)))
      )

  let top_accounts_encoding =
    def "top_accounts"
      ~title:"Top Accounts"
      ~description:"Top accounts" @@
    conv
      (fun
        { top_period ; top_kind ; top_hash ; top_list }
        ->
          ( top_period , top_kind , top_hash , top_list )
      )
      (fun
        ( top_period , top_kind , top_hash , top_list )
        ->
          { top_period ; top_kind ; top_hash ; top_list }
      )
      (obj4
         (req "period" string)
         (req "kind" string)
         (req "block" string)
         (req "list" (list (tup2 account_name_encoding int64)))
      )

end

module WWW = struct

  let name_from_id s =
    String.mapi
      (fun i c ->
         if i = 0 then Char.uppercase_ascii c
         else if c = '_' then ' '
         else c)
      s

  let www_server_info =
    conv
      (fun
        { www_currency_name ; www_currency_short ; www_currency_symbol ;
          www_languages ; www_apis ; www_auth ; www_logo ; www_footer ;
          www_networks; www_themes ; www_recaptcha_key ; www_csv_server ;
          www_charts_server } ->
        ( www_currency_name , www_currency_short , www_currency_symbol ,
          www_languages , www_apis , www_auth , www_logo , www_footer ,
          www_networks, www_themes , www_recaptcha_key, www_csv_server ,
          www_charts_server )
      )
      (fun
        ( www_currency_name , www_currency_short , www_currency_symbol ,
          www_languages , www_apis , www_auth , www_logo , www_footer ,
          www_networks, www_themes , www_recaptcha_key , www_csv_server ,
          www_charts_server ) ->
        { www_currency_name ; www_currency_short ; www_currency_symbol ;
          www_languages ; www_apis ; www_auth ; www_logo ; www_footer ;
          www_networks ; www_themes ; www_recaptcha_key ; www_csv_server ;
          www_charts_server }
      )
      (EzEncoding.obj13
         (dft "currency" string "Tezos")
         (dft "currency_short" string "XTZ")
         (dft "currency_symbol" string "#xa729")
         (dft "languages" (list (tup2 string string)) [ "English", "en" ])
         (req "apis" (array string))
         (opt "auth" string)
         (dft "logo" string "tzscan-logo.png")
         (dft "footer" string "footer.html")
         (dft "networks" (list (tup2 string string)) [])
         (dft "themes" (list (tup2 string string)) [ "Light", "default" ])
         (opt "recaptcha_key" string)
         (opt "csv_server" (tup2 string string))
         (opt "charts_server" string)
      )

end

module Coingecko = struct
  let none = Json_encoding.any_value
  let rq s = opt s none
  let coin_encoding =
    def "coins_value"
      ~title:"Coins Value"
      ~description:"Value of some coins" @@
    conv
      (fun {gk_usd; gk_btc}
        -> ((gk_usd, gk_btc, None, None, None),
            ((None, None, None, None, None, None, None, None, None, None, None,
              None, None, None, None, None, None, None, None, None, None, None,
              None, None),
             (None, None, None, None, None, None, None, None, None, None, None,
              None, None, None, None, None, None, None, None, None, None, None,
              None, None))))
      (fun ((gk_usd, gk_btc, _, _, _),
            ((_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _),
             (_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)))
           -> {gk_usd; gk_btc})
      (merge_objs
         (obj5
            (req "usd" float)
            (req "btc" float)
            (rq "eur") (rq "eth") (rq "jpy"))
         (merge_objs
            (EzEncoding.obj24
               (rq "pkr") (rq "ars") (rq "kwd") (rq "myr") (rq "bhd") (rq "inr")
               (rq "czk") (rq "brl") (rq "sar") (rq "sek") (rq "sgd") (rq "dkk")
               (rq "ltc") (rq "aud") (rq "chf") (rq "zar") (rq "xau") (rq "cny")
               (rq "vef") (rq "bdt") (rq "bnb") (rq "clp") (rq "xrp") (rq "huf"))
            (EzEncoding.obj24
               (rq "bmd") (rq "nok") (rq "rub") (rq "mxn") (rq "try") (rq "xdr")
               (rq "mmk") (rq "pln") (rq "php") (rq "hkd") (rq "xlm") (rq "ils")
               (rq "bch") (rq "twd") (rq "lkr") (rq "idr") (rq "krw") (rq "thb")
               (rq "eos") (rq "aed") (rq "gbp") (rq "nzd") (rq "cad") (rq "xag"))))
  let coin_encoding_string =
    conv
      (fun {gk_usd; gk_btc} -> (gk_usd, gk_btc, None))
      (fun (gk_usd, gk_btc, _) -> {gk_usd; gk_btc})
         (obj3
            (req "usd" float)
            (req "btc" float)
            (rq "eth"))

  let market_data_encoding =
    def "market_data"
      ~title:"Market Data"
      ~description:"Market information from Coingecko" @@
    conv
      (fun {gk_price; gk_market_volume; gk_1h; gk_24h; gk_7d}
        -> ((gk_price, gk_market_volume, gk_1h, gk_24h, gk_7d, None, None, None, None,
             None, None, None, None, None, None, None, None),
            (None, None, None, None, None, None, None, None, None, None, None,
             None, None, None, None, None, None)))
      (fun ((gk_price, gk_market_volume, gk_1h, gk_24h, gk_7d, _, _, _, _, _, _, _,
             _, _, _, _, _), (_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _))
        -> {gk_price; gk_market_volume; gk_1h; gk_24h; gk_7d})
    (merge_objs
       (EzEncoding.obj17
          (req "current_price" coin_encoding)
          (req "total_volume" coin_encoding)
          (req "price_change_percentage_1h_in_currency" coin_encoding)
          (req "price_change_percentage_24h_in_currency" coin_encoding)
          (req "price_change_percentage_7d_in_currency" coin_encoding)
          (opt "roi" none)
          (opt "last_updated" none)
          (opt "price_change_24h_in_currency" none)
          (opt "price_change_percentage_1y_in_currency" none)
          (opt "high_24h" none)
          (opt "price_change_percentage_1y" none)
          (opt "market_cap_rank" none)
          (opt "price_change_percentage_30d_in_currency" none)
          (opt "price_change_percentage_200d" none)
          (opt "price_change_percentage_60d" none)
          (opt "market_cap_change_percentage_24h" none)
          (opt "circulating_supply" none))
       (EzEncoding.obj17
          (opt "ath_date" none)
          (opt "price_change_percentage_60d_in_currency" none)
          (opt "total_supply" none)
          (opt "price_change_percentage_14d_in_currency" none)
          (opt "market_cap" none)
          (opt "price_change_percentage_200d_in_currency" none)
          (opt "ath_change_percentage" none)
          (opt "low_24h" none)
          (opt "market_cap_change_24h" none)
          (opt "price_change_percentage_30d" none)
          (opt "price_change_percentage_14d" none)
          (opt "ath" none)
          (opt "market_cap_change_percentage_24h_in_currency" none)
          (opt "market_cap_change_24h_in_currency" none)
          (opt "price_change_percentage_24h" none)
          (opt "price_change_24h" none)
          (opt "price_change_percentage_7d" none)))

  let market_encoding =
    conv
      (fun name -> (name, None, None))
      (fun (name, _, _) -> name)
      (obj3
         (req "name" string)
         (opt "identifier" none)
         (opt "has_trading_incentive" none))
  let ticker_encoding =
    def "ticker"
      ~title:"Ticker"
      ~description:"Ticker information from Coingecko" @@
    conv
      (fun {gk_last; gk_target; gk_tsp; gk_anomaly; gk_converted_last; gk_volume;
            gk_stale; gk_base; gk_converted_volume; gk_market}
        -> (gk_last, gk_target, gk_tsp, gk_anomaly, gk_converted_last, gk_volume,
            gk_stale, gk_base, gk_converted_volume, gk_market,
            None, None, None, None, None, None))
      (fun (gk_last, gk_target, gk_tsp, gk_anomaly, gk_converted_last, gk_volume,
            gk_stale, gk_base, gk_converted_volume, gk_market, _, _, _, _, _, _)
        -> {gk_last; gk_target; gk_tsp; gk_anomaly; gk_converted_last; gk_volume;
            gk_stale; gk_base; gk_converted_volume; gk_market})
      (EzEncoding.obj16
         (req "last" float)
         (req "target" string)
         (req "timestamp" string)
         (req "is_anomaly" bool)
         (req "converted_last" coin_encoding_string)
         (req "volume" float)
         (req "is_stale" bool)
         (req "base" string)
         (req "converted_volume" coin_encoding_string)
         (req "market" market_encoding)
         (opt "coin_id" string)
         (req "trade_url" (option string))
         (req "bid_ask_spread_percentage" (option float))
         (rq "trust_score")
         (opt "last_fetch_at" string)
         (opt "last_traded_at" string)
      )

  let tickers_encoding = list ticker_encoding
  let encoding =
    def "coingecko_tezos"
      ~title:"Coingecko Tezos Information"
      ~description:"Tezos information from Coingecko" @@
    conv
      (fun gk_tickers -> (gk_tickers, None))
      (fun (gk_tickers, _) -> gk_tickers)
      (obj2
         (req "tickers" tickers_encoding)
         (opt "name" none))
  let encoding_full =
    conv
      (fun {gk_last_updated; gk_market_data; gk_tickers}
        -> ((gk_last_updated, gk_market_data, gk_tickers), (None, None, None, None,
            None, None, None, None, None, None, None, None, None, None, None, None,
            None, None, None, None, None, None)))
      (fun ((gk_last_updated, gk_market_data, gk_tickers),(_, _, _, _,
            _, _, _, _, _, _, _, _, _, _, _, _,
            _, _, _, _, _, _))
        -> {gk_last_updated; gk_market_data; gk_tickers})
      (merge_objs
         (obj3
            (req "last_updated" string)
            (req "market_data" market_data_encoding)
            (req "tickers" tickers_encoding))
         (EzEncoding.obj22
            (opt "links" none)
            (opt "image" none)
            (opt "status_updates" none)
            (opt "liquidity_score" none)
            (opt "market_cap_rank" none)
            (opt "id" none)
            (opt "coingecko_score" none)
            (opt "developer_data" none)
            (opt "genesis_date" none)
            (opt "ico_data" none)
            (opt "description" none)
            (opt "localization" none)
            (opt "public_interest_stats" none)
            (opt "symbol" none)
            (opt "public_interest_score" none)
            (opt "community_score" none)
            (opt "categories" none)
            (opt "name" none)
            (opt "community_data" none)
            (opt "country_origin" none)
            (opt "coingecko_rank" none)
            (opt "developer_score" none)))

end

module V3 = struct

  let nb_all_rights =
      (obj2
         (req "nb_bakings" int)
         (req "nb_endorsements" int))

  let account_search = def "account_search" @@
    let encoding =
        (obj2
           (req "search_result" account_name_encoding)
           (req "search_kind" string)) in
    list encoding

  let balance_history =
    let encoding =
        (obj2
           (req "index" int32)
           (req "balance" V1.Balance.encoding)) in
    list encoding

  let rolls_history =
    let encoding =
        (obj3
           (req "cycle" int64)
           (req "roll_count" int32)
           (req "roll_total" int32)) in
    list encoding

  let bakings_history =
      (obj3
         (req "total" V1.CycleBakeOp.bakings)
         (req "rights" V1.CycleRights.rights)
         (req "passed" V1.CycleBakeOp.bakings))

  let endorsements_history =
      (obj3
         (req "total" V1.CycleEndorsementOp.bakings)
         (req "rights" V1.CycleRights.rights)
         (req "passed" V1.CycleEndorsementOp.bakings))

  let balance_ranking = def "balance_ranking" @@
    let encoding =
        (obj3
           (req "rank" int)
           (req "account" account_name_encoding)
           (req "balance" tez)) in
    list encoding

  let last_baking =
      (obj4
         (req "last_baking" V1.BakeOp.bakings)
         (req "last_endorsement" V1.BakeEndorsementOp.bakings)
         (req "last_baking_right" int)
         (req "last_endorsement_right" int))

  let next_baking =
      (obj5
         (req "cycle" int)
         (req "head_level" int)
         (req "next_baking" int)
         (req "next_endorsement" int)
         (req "head_timestamp" string))

  let required_balance =
    let encoding =
        (obj6
           (req "cycle" int)
           (req "required_deposit" tez)
           (req "unfrozen_back" tez)
           (req "cumulated" tez)
           (req "roll_count" int)
           (req "roll_total" int)) in
    list encoding

  let rights =
    let encoding =
      def "baking_endorsing_rights_3"
        ~title:"Baking/Endorsing Rights"
        ~description:"Baking and endorsing rights for a level" @@
      conv
        (fun ({ r_level; r_bakers; r_endorsers ; r_bakers_priority; r_baked})
          -> (r_level, r_bakers, r_endorsers, r_bakers_priority, r_baked))
        (fun (r_level, r_bakers, r_endorsers, r_bakers_priority, r_baked)
          -> ({ r_level; r_bakers; r_endorsers; r_bakers_priority; r_baked}))
        (obj5
           (req "level" int)
           (req "bakers" (list account_name_encoding))
           (req "endorsers" (list account_name_encoding))
           (req "bakers_priority" (list int))
           (opt "baked" (obj2 (req "account" account_name_encoding) (req "priority" int))))
    in list encoding

  let rewards_split =
    def "delegate_rewards_3"
      ~title:"Delegate Rewards"
      ~description:"Information about delegate rewards" @@
    conv
      (fun { rs_delegate_staking_balance ; rs_delegators_nb ;
             rs_delegators_balance ; rs_block_rewards ;
             rs_endorsement_rewards ; rs_fees ;
             rs_baking_rights_rewards ; rs_endorsing_rights_rewards ;
             rs_gain_from_denounciation ; rs_lost_deposit ;
             rs_lost_rewards ; rs_lost_fees;
             rs_rv_rewards; rs_rv_lost_rewards; rs_rv_lost_fees } ->
        ( rs_delegate_staking_balance, rs_delegators_nb,
          rs_delegators_balance, rs_block_rewards,
          rs_endorsement_rewards, rs_fees, rs_baking_rights_rewards,
          rs_endorsing_rights_rewards,
          rs_gain_from_denounciation, rs_lost_deposit,
          rs_lost_rewards, rs_lost_fees,
          rs_rv_rewards, rs_rv_lost_rewards, rs_rv_lost_fees))
      (fun ( rs_delegate_staking_balance, rs_delegators_nb,
             rs_delegators_balance, rs_block_rewards,
             rs_endorsement_rewards, rs_fees, rs_baking_rights_rewards,
             rs_endorsing_rights_rewards,
             rs_gain_from_denounciation, rs_lost_deposit,
             rs_lost_rewards, rs_lost_fees,
             rs_rv_rewards, rs_rv_lost_rewards, rs_rv_lost_fees) ->
        { rs_delegate_staking_balance ; rs_delegators_nb ;
          rs_delegators_balance ; rs_block_rewards ;
          rs_endorsement_rewards ; rs_fees ;
          rs_baking_rights_rewards ; rs_endorsing_rights_rewards ;
          rs_gain_from_denounciation ; rs_lost_deposit ;
          rs_lost_rewards ; rs_lost_fees;
          rs_rv_rewards; rs_rv_lost_rewards; rs_rv_lost_fees})
      (EzEncoding.obj15
         (req "delegate_staking_balance" int64)
         (req "delegators_nb" int)
         (req "delegators_balance"
            (list (obj2 (req "account" account_name_encoding) (req "balance" tez))))
         (req "blocks_rewards" int64)
         (req "endorsements_rewards" int64)
         (req "fees" int64)
         (req "future_blocks_rewards" int64)
         (req "future_endorsements_rewards" int64)
         (req "gain_from_denounciation" int64)
         (req "lost_deposit_from_denounciation" int64)
         (req "lost_rewards_denounciation" int64)
         (req "lost_fees_denounciation" int64)
         (req "revelation_rewards" tez)
         (req "lost_revelation_rewards" tez)
         (req "lost_revelation_fees" tez))
end


let exchange_info_encoding =
  let ticker_encoding =
    conv
      (fun {ex_base; ex_target; ex_volume; ex_conversion; ex_price_usd; ex_tsp}
        -> (ex_base, ex_target, ex_volume, ex_conversion, ex_price_usd, ex_tsp))
      (fun (ex_base, ex_target, ex_volume, ex_conversion, ex_price_usd, ex_tsp)
        -> {ex_base; ex_target; ex_volume; ex_conversion; ex_price_usd; ex_tsp})
      (obj6
         (req "base" string)
         (req "target" string)
         (req "volume" float)
         (req "conversion" float)
         (req "price_usd" float)
         (req "timestamp" string)) in
  conv
    (fun {ex_name; ex_total_volume; ex_tickers}
      -> (ex_name, ex_total_volume, ex_tickers))
    (fun (ex_name, ex_total_volume, ex_tickers)
      -> {ex_name; ex_total_volume; ex_tickers})
    (obj3
       (req "name" string)
       (req "total_volume" float)
       (req "tickers" (list ticker_encoding)))

module Services = struct
  let multiline =
    union [
      case
        (list string)
        (fun s ->
           match OcpString.split s '\n' with
             [] | [_] -> None
           | list -> Some list)
        (fun list -> String.concat "\n" list);
      case string (fun s -> Some s) (fun s -> s)
    ]

  let service =
    conv
      (fun { srv_kind; srv_tz1; srv_name; srv_url; srv_logo; srv_logo2;
             srv_logo_payout; srv_descr; srv_sponsored; srv_page;
             srv_delegations_page ; srv_account_page ; srv_aliases ;
             srv_display_delegation_page ; srv_display_account_page }
        -> ( srv_kind, srv_tz1, srv_name, srv_url, srv_logo, srv_logo2,
             srv_logo_payout, srv_descr, srv_sponsored, srv_page,
             srv_delegations_page, srv_account_page, srv_aliases,
             srv_display_delegation_page, srv_display_account_page ) )
      (fun ( srv_kind, srv_tz1, srv_name, srv_url, srv_logo, srv_logo2,
             srv_logo_payout, srv_descr, srv_sponsored, srv_page,
             srv_delegations_page, srv_account_page, srv_aliases,
             srv_display_delegation_page, srv_display_account_page)
        -> { srv_kind; srv_tz1; srv_name; srv_url; srv_logo; srv_logo2;
             srv_logo_payout; srv_descr; srv_sponsored; srv_page;
             srv_delegations_page; srv_account_page; srv_aliases ;
             srv_display_delegation_page ; srv_display_account_page} )
      (EzEncoding.obj15
         (dft "kind" string "delegate")
         (opt "address" string)
         (req "name" string)
         (dft "url" string "")
         (dft "logo" string "")
         (opt "logo2" string)
         (opt "logo_payout" string)
         (opt "descr" multiline)
         (opt "sponsored" string)
         (opt "page" string)
         (dft "delegation-services-page" bool true)
         (dft "account-page" bool true)
         (opt "aliases" (list account_name_encoding))
         (dft "display-delegation-page" bool true)
         (dft "display-account-page" bool true)
      )
  let encoding = list service
end
