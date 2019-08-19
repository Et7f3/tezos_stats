let answer_encoding ok =
  let open Json_encoding in
  obj2 (opt "data" ok) (opt "error" string)

let error_json_encoding = answer_encoding Json_encoding.unit

let token_encoding = answer_encoding Json_encoding.string

let shutdown_encoding = answer_encoding Json_encoding.bool

let register_encoding =
  let open Json_encoding in
  obj1 (req "to" string)

let answer ?data ?error encoding =
  match Json_encoding.construct encoding (data, error) with
    (`A _ | `O _) as v -> v
  | _ -> assert false

let ask encoding data =
  match Json_encoding.construct encoding data with
    (`A _ | `O _) as v -> Ezjsonm.to_string v
  | _ -> assert false