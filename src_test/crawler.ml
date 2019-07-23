(*type a = A | B [@@deriving yojson]
let a = a_to_yojson A
let () = print_endline (Yojson.Safe.to_string a)
#require "cohttp-lwt-unix";;
open Lwt;;
open Cohttp;;
open Cohttp_lwt_unix;;

let make_rpc uri =
  let uri = Uri.of_string uri in
  (Client.get uri >>= fun (resp, body) -> let code = resp |> Response.status |> Code.code_of_status in let body = body |> Cohttp_lwt.Body.to_string |> Lwt_main.run in return (code, body)) |> Lwt_main.run;;

let code, body = make_rpc "http://tz.api1.tzscan.io/network/stat";;
*)
