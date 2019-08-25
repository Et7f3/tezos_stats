open Opium.Std

let a =
  App.empty
  |> middleware (Middleware.static ~local_path:"lib/js/src/web_client" ~uri_prefix:"/static/js" ())
  |> middleware (Middleware.static ~local_path:"src/web_assets" ~uri_prefix:"/" ())
  |> App.run_command'

let () =
  match a with
    `Ok w ->
    let () = print_endline "We static js and html" in
    Lwt_main.run w
  | `Error -> print_endline "error"
  | `Not_running -> print_endline "not running"
