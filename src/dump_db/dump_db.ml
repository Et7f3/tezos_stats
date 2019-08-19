let dbh = PGOCaml.connect ()

(*
   let () =
   let insert name token =
   [%pgsql dbh "insert into register (name, token, register_date) VALUES ($name, $token, NOW())"]
   in
   ignore(insert "name" "generated_token")

   let () =
   let insert name =
   [%pgsql dbh "insert into scan (name, build_date) VALUES ($name, NOW())"]
   in
   ignore(insert "name")
*)

let print_db select f =
  let select = List.map f select in
  let select_s = List.map String.length select |> List.fold_left max 0 in
  let sep = String.make select_s '_' in
  let () = Printf.printf "%d row\r\n%s\r\n" (List.length select) sep in
  List.iter (fun s -> Printf.printf "%s\r\n%s\r\n" s sep) select

let string_of_int32_option = function
    None -> ""
  | Some e -> PGOCaml.string_of_int32 e

let string_of_timestamp_option = function
    None -> ""
  | Some e -> PGOCaml.string_of_timestamp e

let string_of_string_option = function
    None -> ""
  | Some e -> e

let string_of_date_option = function
    None -> ""
  | Some e -> PGOCaml.string_of_date e

let () = print_db [%pgsql dbh "select * from scan"]
           (fun (a, b, c, d, e, f, g, h, i, j, k, l) ->
              let open PGOCaml in
              let b = string_of_int32_option b in
              let c = string_of_timestamp_option c in
              let d = string_of_string_option d in
              let e = string_of_int32 e in
              let f = string_of_string_option f in
              let g = string_of_int32 g in
              let h = string_of_int32 h in
              let i = string_of_string_option i in
              let j = string_of_string_option j in
              let k = string_of_date_option k in
              let l = string_of_string_option l in
              Printf.sprintf "|%s|%s|%20s|%60s|%s|%s|%s|%s|%s|%s|%10s|%s|" a b c d e f g h i j k l)

let () = print_db [%pgsql dbh "select * from register"]
           (fun (a, b, c) ->
              let open PGOCaml in
              let c = string_of_timestamp c in
              Printf.sprintf "|%42s|%42s|%20s|" a b c)

let () = PGOCaml.close dbh