open Opium.Std
open Main_to_db


let answer ?data ?error encoding =
  respond' (`Json (answer ?data ?error encoding))

let destruct encoding req f =
  let req =
    Lwt.catch (fun () -> App.json_of_body_exn req)
      (fun error ->
         let _ =
           Lwt_io.eprintf "JSON not a array or object\r\n%s\r\n"
             (Printexc.to_string error)
         in Lwt.fail error)
  in let req = (req :> Json_repr.ezjsonm Lwt.t) in
  Lwt.bind req (fun json ->
                 try
                   f (Json_encoding.destruct encoding json)
                 with error ->
                   let error = Printexc.to_string error in
                   let _ = Lwt_io.eprintf "%s\r\n" error in
                   answer ~error:"Bad JSON Value" error_json_encoding)

let () = Random.self_init ()

(* init db *)
let dbh = PGOCaml.connect ()

(*let () = [%pgsql dbh "execute" "DROP TABLE IF EXISTS scan"]*)

let () =
  [%pgsql dbh
            "execute"
            "CREATE TABLE IF NOT EXISTS scan (
      name TEXT PRIMARY KEY,
      head_level INT DEFAULT 0,
      head_time TIMESTAMP,
      head_hash CHAR(60),
      peers INT NOT NULL DEFAULT 0,
      version TEXT,
      in_flaw INT NOT NULL DEFAULT 0,
      out_flaw INT NOT NULL DEFAULT 0,
      build_commit TEXT,
      build_branch TEXT,
      build_date DATE,
      checkpoint_type TEXT)"]

let () =
  [%pgsql dbh
            "execute"
            "CREATE TABLE IF NOT EXISTS register (
      name TEXT PRIMARY KEY NOT NULL,
      token TEXT NOT NULL,
      register_date TIMESTAMP NOT NULL)"]

let () = Sys.catch_break true

let () =
  at_exit
    (fun () ->
       let () = print_endline "We close handle to DB" in
       PGOCaml.close dbh |> ignore)

let get_token name =
  [%pgsql dbh "SELECT token FROM register where name = $name"]

let register id =
  let registered_token = get_token id in
  match List.length registered_token with
    0 ->
    let alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz" in
    let token = Bytes.init 42 (fun _ -> alphabet.[Random.int 62]) in
    let token = Bytes.to_string token in
    let () =
      (* we shouldn't have to try..with *)
      [%pgsql dbh "INSERT INTO register (name, token, register_date)
                                 VALUES ($id, $token, NOW())"]
    in answer ~data:token ?error:None
  | 1 -> answer ?data:None ~error:"Already registered"
  | _ -> answer ?data:None ~error:"Something went wrong"

let register =
  post "/register" begin fun req ->
    destruct register_encoding req (fun id -> register id token_encoding)
  end

let shutdown_server =
  get "/stop/:host_password" begin fun req ->
    if param req "host_password" = Sys.getenv "host_password" then
      let shut = answer ~data:true shutdown_encoding in
      Lwt.bind shut (fun _ -> exit 0)
    else
      answer ~error:"Unauthorized" shutdown_encoding
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