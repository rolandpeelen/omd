include Js.String
open Utils

let equal = ( == )
let sliceToEnd start t = Js.String.slice ~start ~end_:(t |> length) t
let head = Js.String.charAt ~index:0
let tail = sliceToEnd 1
let split sep = Js.String.split ~sep ~limit:(-1)
let to_char s = Stdlib.String.get s 0
let from_char = Stdlib.String.make 1
let sub s off len = Js.String.slice ~start:off ~end_:(off + len) s
let iter f = Js.String.split ~sep:"" >> Js.Array.forEach ~f
let reduce f init = Js.String.split ~sep:"" >> Js.Array.reduce ~init ~f

let rec intersperse sep = function
  | [] | [ _ ] -> ""
  | x :: xs -> x ^ sep ^ intersperse sep xs

let intercalate = Stdlib.String.concat
