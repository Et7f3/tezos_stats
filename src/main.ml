type config =
  {
    target: string;
    delay_head: float;
    delay_peers: float;
  }

let read_config config_file =
  let yojson = Yojson.Safe.from_file ~fname:"config" config_file in
  let ezjsonm = Json_repr.from_yojson yojson in
  let encoding =
    let open Json_encoding in
    obj3 (req "target" string) (opt "delay_head" float)
      (opt "delay_peers" float)
  in let target, delay_head, delay_peers =
    Json_encoding.destruct encoding ezjsonm
  in let delay_head =
    match delay_head with
      Some delay_head -> delay_head
    | None -> 10.
  in let delay_peers =
    match delay_peers with
      Some delay_peers -> delay_peers
    | None -> 60.
  in {
    target;
    delay_head;
    delay_peers;
  }

let config =
  try
    read_config "config.json"
  with
  (* hack during development *)
  | _ -> read_config "src/config.json"

let fetch msg delay =
  Printf.printf "We will fetch %s every %f second%s" msg delay
    (if delay > 2. then "s\n" else "\n")

let destruct encoding data =
  let yojson = Yojson.Safe.from_string data in
  let ezjsonm = Json_repr.from_yojson yojson in
  Json_encoding.destruct encoding ezjsonm

let () = print_endline "config loaded"
let () = print_endline ("We will monitor: " ^ config.target)
let () = fetch "head" config.delay_head
let () = fetch "peers" config.delay_peers

let print_head =
  (* We don't use None / Some _ to avoid indirection *)
  let last_head = ref "" in
  function head ->
    let head = destruct Json_encoding.string head in
    if !last_head <> head then
      let () = last_head := head in
      print_endline (config.target ^ " is at " ^ head)

let rec peek_head =
  let url = EzAPI.TYPES.URL (config.target ^ "/chains/main/blocks/head/hash")
  and error = fun i -> function
      Some s -> Printf.eprintf "A request has failed with error n: %s" s
    | None -> Printf.eprintf "A request has failed with error n"
  in function () ->
    let ret, _resolver = Lwt.wait () in
    let () =
      EzCohttp.get __LOC__ url ~error
        (fun s ->
          let () = print_head s in
          let sleep = Lwt_unix.sleep config.delay_head in
          let _ = Lwt.bind sleep peek_head in
          ())
    in
    ret

let print_peers =
  (* We won't have -1 peer*)
  let last_number_peers = ref ~-1 in
  function peers ->
    let peers =
      destruct Ocplib_tezos.Tezos_encoding.Encoding.Network.encoding peers
    in let peers =
      List.filter Ocplib_tezos.Tezos_types.(fun e -> e.state <> Disconnected)
        peers
    in let num = List.length peers in
    if !last_number_peers <> num then
      let () = last_number_peers := num in
      Printf.printf "%s as %d active or running peer%s" config.target num
        (if num > 2 then "s\n" else "\n")

let rec peek_peers =
  let url = EzAPI.TYPES.URL (config.target ^ "/network/peers")
  and error = fun i -> function
      Some s -> Printf.eprintf "A request has failed with error n: %s" s
    | None -> Printf.eprintf "A request has failed with error n"
  in function () ->
    let ret, _resolver = Lwt.wait () in
    let () =
      EzCohttp.get __LOC__ url ~error
        (fun s ->
          let () = print_peers s in
          let sleep = Lwt_unix.sleep config.delay_peers in
          let _ = Lwt.bind sleep peek_peers in
          ())
    in
    ret

let () = Lwt.join [peek_head (); peek_peers ()] |> Lwt_main.run