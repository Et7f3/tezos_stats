type config =
  {
    target: string;
    delay_head: float;
  }

let read_config config_file =
  let yojson = Yojson.Safe.from_file ~fname:"config" config_file in
  let ezjsonm = Json_repr.from_yojson yojson in
  let encoding =
    let open Json_encoding in
    obj2 (req "target" string) (opt "delay_head" float)
  in let target, delay_head = Json_encoding.destruct encoding ezjsonm in
  let delay_head =
    match delay_head with
      Some delay_head -> delay_head
    | None -> 10.
  in {
    target;
    delay_head;
  }

let config =
  try
    read_config "config.json"
  with
  (* hack during development *)
  | _ -> read_config "src/config.json"

let () = print_endline "config loaded"
let () = print_endline ("We will monitor: " ^ config.target)
let () =
  Printf.printf "We will fetch head every %f second%s" config.delay_head
    (if config.delay_head > 2. then "s\n" else "\n")

let print_head head =
  print_endline (config.target ^ " is at " ^ head)

let rec peek_head =
  let url = EzAPI.TYPES.URL (config.target ^ "/chains/main/blocks/head/hash")
  and error = fun i -> function
      Some s -> Printf.eprintf "A request has failed with error n: %s" s
    | None -> Printf.eprintf "A request has failed with error n"
  in function () ->
    let ret, _resolver = Lwt.wait () in
    let () =
      EzCohttp.get "peek_head" url ~error
        (fun s ->
          let () = print_head s in
          let sleep = Lwt_unix.sleep config.delay_head in
          let _ = Lwt.bind sleep peek_head in
          ())
    in
    ret

let () = peek_head () |> Lwt_main.run