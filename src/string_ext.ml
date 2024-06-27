let reduce f init s = s 
        |> Js.String.split ~sep:"" 
        |> Js.Array.reduce ~init ~f
