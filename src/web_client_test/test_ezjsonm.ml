open Bs_fake_ezjsonm
let test_encoding = Json_encoding.(obj2 (req "a" int) (opt "bs" string))
let original_data = {|{"a":42,"bs":"bucklescript"}|}
let ezjsonm = ezjsonm_of_string original_data
let obj = Json_encoding.destruct test_encoding ezjsonm
let () = assert (Json_encoding.construct test_encoding obj = ezjsonm)
let () = assert (string_of_ezjsonm ezjsonm = original_data)