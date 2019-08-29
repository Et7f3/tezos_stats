open Websocket

let ws = Hashtbl.create ~random:true 100

let string_of_conn conn =
  Sexplib.Sexp.to_string (Cohttp.Connection.sexp_of_t conn)

let websocket_handler (_, conn_id) req body =
  let body = Cohttp_lwt.Body.drain_body body in
  let req =
    Lwt.bind body
      (fun () ->
         Websocket_cohttp_lwt.upgrade_connection req
           (fun {opcode; content; _} ->
              match opcode with
                Frame.Opcode.Close -> Hashtbl.remove ws conn_id
              | _ ->
                Lwt.async
                  (fun () ->
                     Lwt_io.eprintf "%s send %s\n" (string_of_conn conn_id)
                       content)))
  in Lwt.bind req
       (fun (resp, frames_out_fn) ->
          let () = Hashtbl.add ws conn_id frames_out_fn in
          Lwt.return resp)

let start_websocket_server ?tls port =
  let conn_closed (_, conn_id) =
    Lwt.async
      (fun () ->
         Lwt_io.printf "Connection %s closed\n" (string_of_conn conn_id))
  in
  let mode =
    match tls with
      None ->
      let () = Printf.printf "Listen for HTTP on port %d" port in
      `TCP (`Port port)
    | Some (cert, key) ->
      let () = Printf.printf "Listen for HTTPS on port %d" port in
      `TLS (`Crt_file_path cert, `Key_file_path key, `No_password, `Port port)
  in Cohttp_lwt_unix.Server.create ~mode
       (Cohttp_lwt_unix.Server.make_response_action ~callback:websock_handler
          ~conn_closed ())
