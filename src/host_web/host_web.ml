open Opium.Std

let a =
  App.empty
  |> middleware (Middleware.static ~local_path:"lib/js/src/web_client" ~uri_prefix:"/static/js" ())
  |> App.run_command'

let () =
  match a with
    `Ok w ->
    let () = print_endline "We static js" in
    Lwt_main.run w
  | `Error -> print_endline "error"
  | `Not_running -> print_endline "not running"
