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

let () = print_endline "e"

let dbh = PGOCaml.close(dbh)

open Opium.Std

type person = {
  name: string;
  age: int;
}
let json_of_person { name ; age } =
  let open Ezjsonm in
  dict [ "name", (string name)
       ; "age", (int age) ]

let print_param =
  put "/hello/:name" begin fun req ->
    `String ("Hello " ^ param req "name") |> respond'
  end

let print_person =
  get "/person/:name/:age" begin fun req ->
    let person = {
      name = param req "name";
      age = "age" |> param req |> int_of_string;
    } in
    `Json (person |> json_of_person) |> respond'
  end

let a =
  App.empty
  |> print_param
  |> print_person
  |> App.run_command'

let () =
  match a with
    `Ok w ->
    let () = print_endline "We launch server" in
    Lwt_main.run w
  | `Error -> print_endline "error"
  | `Not_running -> print_endline "not running"