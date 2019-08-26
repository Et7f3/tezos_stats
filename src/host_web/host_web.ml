open Opium.Std

let ws = all "/ws" (fun req ->
                     let drain =
                       req
                       |> Request.body
                       |> Cohttp_lwt.Body.drain_body
                     in
                     let req =
                       Lwt.bind drain (fun () ->
                                        let req = req.request in
                                        Websocket_cohttp_lwt.upgrade_connection
                                          req begin fun { opcode ; content ; _ } ->
                                          let () = Printf.printf "recv" in
                                          let () = flush stdout in
                                          match opcode with
                                          | Websocket.Frame.Opcode.Close ->
                                            let _ = Lwt_io.printf "closed" in
                                            ()
                                          | _ ->
                                            let _ = Lwt_io.printf "receved %s" content in
                                            ()
                                        end)
                     in
                     Lwt.bind req (fun ((`Expert (res, _) | `Response (res, _)), frames_out_fn) ->
                                    let () = Printf.printf "output res" in
                                    let () = flush stdout in
                                    let () = frames_out_fn (Some (Websocket.Frame.create ~content:"hello there" ())) in
                                    let res = Opium_kernel.Response.create ~headers: res.headers ~code:res.status() in
                                    Lwt.return res))

let a =
  App.empty
  |> middleware (Middleware.static ~local_path:"lib/js/src/web_client" ~uri_prefix:"/static/js" ())
  |> middleware (Middleware.static ~local_path:"src/web_assets" ~uri_prefix:"/" ())
  |> ws
  |> App.run_command'

let () =
  match a with
    `Ok w ->
    let () = print_endline "We static js and html" in
    Lwt_main.run w
  | `Error -> print_endline "error"
  | `Not_running -> print_endline "not running"
