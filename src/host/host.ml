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