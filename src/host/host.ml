let () =
  let dbh = PGOCaml.connect () in
  let insert name salary =
    [%pgsql dbh "insert into employees (name, salary) VALUES ($name, $salary)"]
  in
  ignore(insert "Chris" 1_000.0);
  let get name =
    [%pgsql dbh "select salary from employees where name = $name"]
  in
  let () = [%pgsql dbh
                     "execute"
                     "CREATE TEMP TABLE IF NOT EXISTS employees (
        name TEXT PRIMARY KEY,
        salary FLOAT)"]
  in
  let name = "Chris" in
  let salary = get name
               |> List.hd
               |> function
               | Some(x) -> x
               | None -> raise(Failure "The database is probably broken.")
  in
  Printf.printf "%s's salary is %.02f\n" name salary;
  PGOCaml.close(dbh)