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
open Tezos_types
open Data_types

let tezos_constants = ref []

type net =
  | Alphanet
  | Zeronet
  | Betanet

let net = match TzscanConfig.database with
  | "mainnet" -> Betanet
  | "betanet" -> Betanet
  | "zeronet" -> Zeronet
  | "alphanet" -> Alphanet
  | "beta" -> Betanet
  | "next" -> Betanet
  | "local" -> Betanet
  | _ -> assert false

let tez_units = 1_000_000L

let versions =
  {
    server_version = TzscanConfig.version;
    server_build = TzscanConfig.en_date;
    server_commit = TzscanConfig.commit;
  }

let betanet = {
  ico_company_tokens = 76431859_801260L ;
  ico_foundation_tokens = 76431859_801260L ;
  ico_early_tokens = 3_156_502_294100L ;
  ico_contributors_tokens = 608_297_709_519372L ;
  ico_wallets = 31524 ;
}

(*
let alphanet = {
  ico_company_tokens = 0L ;
  ico_foundation_tokens = 32_000_000_000000L ;
  ico_early_tokens = 0L ;
  ico_contributors_tokens = 760_000_000_000000L ;
  ico_wallets = 30_000 ;
}

let zeronet = {
  ico_company_tokens = 0L ;
  ico_foundation_tokens = 8_040_000_000000L ;
  ico_early_tokens = 0L ;
  ico_contributors_tokens = 760_000_000_000000L ;
  ico_wallets = 30_000 ;
}
*)

let api =
  let api_config =
    {
      conf_network = "Mainnet" ;
      conf_constants = [];
      conf_ico = betanet;
      conf_has_delegation = false ;
      conf_has_marketcap = false ;
    }
  in
  let api_date = 0. in
  let api_versions  = {
    server_version = "--" ;
    server_build = "--" ;
    server_commit = "--" ;
  }
  in
  {
    api_config ;
    api_date ;
    api_versions ;
  }


let www = {
  www_currency_name = "Tezos" ;
  www_currency_short = "XTZ" ;
  www_currency_symbol =  "#xa729" ;
  www_languages = [ "English", "en" ; "Français", "fr" ] ;
  www_apis = [||] ;
  www_auth = None ;
  www_logo = "tzscan-logo.png" ;
  www_footer = "/footer.html" ;
  www_networks = [] ;
  www_themes = [ "Light", "default"; "Dark", "slate" ] ;
  www_recaptcha_key = None;
  www_csv_server = None;
  www_charts_server = None ;
}

let save_api_config filename =
  let oc = open_out filename in
  output_string oc (EzEncoding.construct ~compact:false
                      Api_encoding.V1.Server.api_server_config
                      api.api_config);
  close_out oc

let init_constants csts =
  (* constants input should be in increasing order *)
  let csts = List.fold_left (fun acc (cycle, cst) -> match acc with
      | (_, c) :: _ when c = cst -> acc
      | acc -> (cycle, cst) :: acc) [] csts in
  tezos_constants := csts;
  api.api_config.conf_constants <- !tezos_constants

let add_constants cycle cst =
  let rec iter = function
    | (c, co) :: t when c > cycle -> (c, co) :: (iter t)
    | (c, co) :: t when c = cycle || co = cst -> (c, co) :: t
    | l -> (cycle, cst) :: l in
  tezos_constants := iter !tezos_constants;
  api.api_config.conf_constants <- !tezos_constants

let constants ~cycle =
  let rec iter = function
    | [] -> assert false
    | (cy , c) :: _ when cycle >= cy -> c
    | _ :: t -> iter t in
  iter !tezos_constants

let cycle_from_level ~cst level =
  (level - 1) / cst.blocks_per_cycle
