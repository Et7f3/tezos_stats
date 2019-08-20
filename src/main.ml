type node =
  {
    token : string option;
    target : string;
  }

type config =
  {
    nodes: node list;
    delay_head: float;
    delay_peers: float;
  }

let config_encoding =
  let open Json_encoding in
  let node_encoding =
    conv (fun {token; target;} -> token, target)
      (fun (token, target) -> {token; target;})
      (obj2 (opt "token" string) (req "target" string))
  in let encoding =
       obj3 (req "nodes" (list node_encoding)) (dft "delay_head" float 10.)
         (dft "delay_peers" float 60.)
  in
  conv
    (fun {nodes; delay_head; delay_peers;} -> nodes, delay_head, delay_peers)
    (fun (nodes, delay_head, delay_peers) -> {nodes; delay_head; delay_peers;})
    encoding

let read_config config_file =
  let yojson = Yojson.Safe.from_file ~fname:"config" config_file in
  let ezjsonm = Json_repr.from_yojson yojson in
  Json_encoding.destruct config_encoding ezjsonm

let config, config_path =
  try
    let path = "config.json" in
    read_config path, path
  with
  (* hack during development *)
  | _ ->
    let path = "src/config.json" in
    read_config path, path

let write_config () =
  let ezjsonm = Json_encoding.construct config_encoding config in
  let yojson = Json_repr.to_yojson ezjsonm in
  Yojson.Safe.to_file config_path yojson

let () = write_config ()

let fetch msg delay =
  Printf.printf "We will fetch %s every %f second%s" msg delay
    (if delay > 2. then "s\n" else "\n")

let destruct encoding data =
  let yojson = Yojson.Safe.from_string data in
  let ezjsonm = Json_repr.from_yojson yojson in
  Json_encoding.destruct encoding ezjsonm

let () = print_endline "config loaded"
let () =
  List.iter (fun config -> print_endline ("We will monitor: " ^ config.target))
    config.nodes
let () = fetch "head" config.delay_head
let () = fetch "peers" config.delay_peers

let generate_crawler_URL root url_name url inital_value encoding error delay
      action =
  let last_value = ref inital_value
  and url = EzAPI.TYPES.URL (root ^ url)
  and error =
    match error with
      Some error -> error
    | None ->
      (fun _i -> function
           Some s -> Printf.eprintf "A request has failed with error n: %s" s
         | None -> Printf.eprintf "A request has failed with error n")
  and ret, _resolver = Lwt.wait ()
  in let rec peek_URL =
       function () ->
         let () =
           EzCohttp.get url_name url ~error
             (fun s ->
                let value = destruct encoding s in
                let () = last_value := action !last_value value in
                let sleep = Lwt_unix.sleep delay in
                let _ = Lwt.bind sleep peek_URL in
                ())
         in
         ret
  in peek_URL ()

let peek_head node_config =
  let print_head head = print_endline (node_config.target ^ " is at " ^ head) in
  generate_crawler_URL node_config.target "peek_head"
    "/chains/main/blocks/head/hash" "" Json_encoding.string None
    config.delay_head
    (function last_head ->
     function head ->
       let () =
         if last_head <> head then
           print_head head
       in head)

let peek_peers node_config =
  let print_peers num =
    Printf.printf "%s as %d active or running peer%s" node_config.target num
      (if num > 2 then "s\n" else "\n")
  in generate_crawler_URL node_config.target "peek_peers"
       "/network/peers" ~-1
       (Ocplib_tezos.Tezos_encoding.Encoding.Network.encoding) None
       config.delay_peers
       (function last_number_peers ->
        function peers ->
          let peers =
            List.filter
              Ocplib_tezos.Tezos_types.(fun e -> e.state <> Disconnected) peers
          in let num = List.length peers in
          let () =
            if last_number_peers <> num then
              print_peers num
          in num)

let peek_node node_config =
  Lwt.join [peek_head node_config; peek_peers node_config]

let () = List.map peek_node config.nodes |> Lwt.join |> Lwt_main.run