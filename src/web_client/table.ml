open Shortcut

let make prop =
  table
    [|
      thead
        [|
          tr (Array.map (fun s -> th [| React.string s |]) prop##headers)
        |];
      tbody
        (Array.map
           (fun row ->
              tr (Array.map
                    (fun s -> th [| React.string s |]) row)) prop##body);
    |]