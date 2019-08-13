open Opium.Std
open Main_to_db

(* init db *)
let dbh = PGOCaml.connect ()

(*let () = [%pgsql dbh "execute" "DROP TABLE scan"]*)

let () =
  [%pgsql dbh
            "execute"
            "CREATE TABLE IF NOT EXISTS scan (
      name TEXT PRIMARY KEY,
      head_level INT,
      head_time TIMESTAMP,
      head_hash CHAR(60),
      peers INT,
      version TEXT,
      in_flaw INT,
      out_flaw INT,
      build_commit TEXT,
      build_branch TEXT,
      build_date DATE,
      checkpoint_type TEXT)"]

let () =
  [%pgsql dbh
            "execute"
            "CREATE TABLE IF NOT EXISTS register (
      name TEXT PRIMARY KEY,
      token TEXT,
      register_date TIMESTAMP)"]

let () = Sys.catch_break true

let () =
  at_exit
    (fun () ->
       let () = print_endline "We close handle to DB" in
       PGOCaml.close dbh |> ignore)

let register =
  get "/register" begin fun _req ->
    `String (ok ()) |> respond'
  end

let shutdown_server =
  get "/stop/:host_password" begin fun req ->
    if param req "host_password" = Sys.getenv "host_password" then
      exit 0
    else
      `String (error "Unauthorized") |> respond'
  end

let a =
  App.empty
  |> register
  |> shutdown_server
  |> App.run_command'

let () =
  match a with
    `Ok w ->
    let () = print_endline "We launch server" in
    Lwt_main.run w
  | `Error -> print_endline "error"
  | `Not_running -> print_endline "not running"