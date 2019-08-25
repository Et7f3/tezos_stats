let () = Polyfill.linkme

let ezjsonm_of_string : string -> Json_repr.ezjsonm = fun data ->
  let json = Js.Json.parseExn data in
  let rec traverse t =
    match Js.Json.classify t with
      JSONArray arr -> `A (List.map traverse (Array.to_list arr))
    | JSONFalse -> `Bool false
    | JSONTrue -> `Bool true
    | JSONNumber n -> `Float n
    | JSONNull -> `Null
    | JSONObject o ->
      let o = Js.Dict.entries o in
      `O (Array.to_list (Array.map (function (s, t) -> s, traverse t) o))
    | JSONString s -> `String s
  in traverse json

let string_of_ezjsonm : Json_repr.ezjsonm -> string = fun json ->
  let rec traverse = function
      `A arr -> Js.Json.array (Array.of_list (List.map traverse arr))
    | `Bool false -> Js.Json.boolean false
    | `Bool true -> Js.Json.boolean true
    | `Float n -> Js.Json.number n
    | `Null -> Js.Json.null
    | `O o ->
      let o = List.map (fun (s, t) -> (s, traverse t)) o in
      Js.Json.object_  (Js.Dict.fromList o)
    | `String s -> Js.Json.string s
  in Js.Json.stringify (traverse json)

let a = Json_encoding.construct
let () = print_endline "Hello"
