include Stdlib.Array

let head xs = get xs 0
let sliceToEnd start t = Js.Array.slice ~start ~end_:(t |> length) t
let tail xs = sliceToEnd 1 xs

let join sep = Js.Array.join ~sep
