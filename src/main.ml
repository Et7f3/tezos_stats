(*
let () = print_endline "e"
let a = 4
let error: EzRequest.error_handler = Printf.(fun i -> function None -> printf " None%d" i | Some s -> printf " %s %d" s i)
let error: EzRequest.error_handler = Printf.(fun i -> function None -> failwith " None"| Some s -> failwith s)
let e = ref false
let mut = Mutex.create ()
let () = Mutex.lock mut
let c = Condition.create ()
let () =
  EzCohttp.get "load-sponsors"
    (EzAPI.TYPES.URL "http://api1.tzscan.io/v1/services") ~error
    (fun s ->
      let () = print_endline "test" in
      let () = print_endline s in
      let () = e := true in
      let () = Condition.signal c in
      flush_all ())
let () = print_endline "e"
let () = Condition.wait c mut
*)

type config =
  {
    nodes: string array;
  }

let read_config config_file =
  let yojson = Yojson.Safe.from_file ~fname:"config" config_file in
  let ezjsonm = Json_repr.from_yojson yojson in
  let nodes = Json_encoding.(destruct (obj1 (req "nodes" (array string))) ezjsonm) in
  {
    nodes
  }

let config =
  try
    read_config "config.json"
  with
  (* hack during development *)
  | _ -> read_config "src/config.json"

let () = print_endline "hello"

let print_head_hash =
  let error: EzRequest.error_handler = Printf.(fun i -> function None -> printf " None%d" i | Some s -> printf " %s %d" s i) in
  function root ->
    let a, b = Lwt.wait () in
    let url = Printf.sprintf "%s/chains/main/blocks/head/hash" root in
    let () = Printf.printf "on accede %s\n" url in
    let () =
      EzCohttp.get "load-sponsors"
        (EzAPI.TYPES.URL url) ~error
        (fun hash ->
          let () = Printf.printf "head %s: %s\n" root hash in
          Lwt.wakeup b ())
    in a

let () = Array.map print_head_hash config.nodes |> Array.iter Lwt_main.run

(* http://tz.next.tzscan.io/chains/main/blocks/head/hash
Json_encoding.(destruct string) (Yojson.Safe.from_string s |> Json_repr.from_yojson);;
*)
(*
let a, b = Lwt.wait ()
let error: EzRequest.error_handler = Printf.(fun i -> function None -> printf " None%d" i | Some s -> printf " %s %d" s i)
let () =
  EzCohttp.get "load-sponsors"
    (EzAPI.TYPES.URL "http://api1.tzscan.io/v1/services") ~error
    (fun s ->
      let () = print_endline "test" in
      let () = print_endline s in
      let () = flush_all () in
      let () = print_endline "on va deverouiller" in
      Lwt.wakeup b 5)

let _ = Lwt_main.run a

let a = 42
*)
