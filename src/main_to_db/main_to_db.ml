type answer = (unit, string) result

let answer =
  let open Json_encoding in
  union [
    case string (function Error s -> Some s | _ -> None)
      (function s -> Error s);
    case unit (function Ok () -> Some () | _ -> None) (function () -> Ok ());
  ]

let ezjsonm_to_string ezjsonm =
  let ezjson =
    (module Json_repr.Ezjsonm : Json_repr.Repr with type value = Json_repr.ezjsonm)
  in
  let () = Json_repr.pp ~compact:true ezjson Format.str_formatter ezjsonm in
  Format.flush_str_formatter ()

let error s =
  Json_encoding.construct answer (Error s) |> ezjsonm_to_string

let ok () =
  Json_encoding.construct answer (Ok ()) |> ezjsonm_to_string