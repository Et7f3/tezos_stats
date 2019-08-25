let ezjsonm_of_string : string -> Json_repr.ezjsonm = fun data ->
  let json = Js.Json.parseExn data in
  let rec traverse t =
    match Js.Json.classify t with
      JSONArray arr ->
      let arr = Array.to_list arr in
      `A (List.map traverse arr)
    | JSONFalse -> `Bool false
    | JSONTrue -> `Bool true
    | JSONNumber n -> `Float n
    | JSONNull -> `Null
    | JSONObject o ->
      let o = Js.Dict.entries o in
      `O (Array.to_list (Array.map (fun (s, t) -> (s, traverse t)) o))
    | JSONString s -> `String s
  in traverse json

let a = Json_encoding.construct
let () = print_endline "Hello"
