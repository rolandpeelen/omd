open Ast.Impl

type element_type =
  | Inline
  | Block
  | Table

type t =
  | Element of element_type * string * attributes * t option
  | Text of string
  | Raw of string
  | Null
  | Concat of t * t

let elt etype name attrs childs = Element (etype, name, attrs, childs)
let text s = Text s
let raw s = Raw s

let concat t1 t2 =
  match (t1, t2) with Null, t | t, Null -> t | _ -> Concat (t1, t2)

let concat_map f l = List.fold_left (fun accu x -> concat accu (f x)) Null l

let concat_map2 f l1 l2 =
  List.fold_left2 (fun accu x y -> concat accu (f x y)) Null l1 l2

(* only convert when "necessary" *)
let htmlentities s =
  let b = Buffer.create (String.length s) in
  let rec loop i =
    if i >= String.length s then Buffer.contents b
    else begin
      begin
        match s.[i] with
        | {|"|} -> Buffer.add_string b "&quot;"
        | "&" -> Buffer.add_string b "&amp;"
        | "<" -> Buffer.add_string b "&lt;"
        | ">" -> Buffer.add_string b "&gt;"
        | s -> Buffer.add_string b s
      end;
      loop (succ i)
    end
  in
  loop 0

let add_attrs_to_buffer buf attrs =
  let f (k, v) = Printf.bprintf buf " %s=\"%s\"" k (htmlentities v) in
  List.iter f attrs

let rec add_to_buffer buf = function
  | Element (eltype, name, attrs, None) ->
      Printf.bprintf buf "<%s%a />" name add_attrs_to_buffer attrs;
      if eltype = Block then Buffer.add_char buf '\n'
  | Element (eltype, name, attrs, Some c) ->
      Printf.bprintf
        buf
        "<%s%a>%s%a</%s>%s"
        name
        add_attrs_to_buffer
        attrs
        (match eltype with Table -> "\n" | _ -> "")
        add_to_buffer
        c
        name
        (match eltype with Table | Block -> "\n" | _ -> "")
  | Text s -> Buffer.add_string buf (htmlentities s)
  | Raw s -> Buffer.add_string buf s
  | Null -> ()
  | Concat (t1, t2) ->
      add_to_buffer buf t1;
      add_to_buffer buf t2

let escape_uri s =
  let b = Buffer.create (String.length s) in
  String.iter
    (function
      | ( "!" | "*" | "\"" | "(" | ")" | ";" | ":" | "@" | "=" | "+" | "$" | ","
        | "/" | "?" | "%" | "#"
        | "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" | "J" | "K" | "L" | "M"
        | "N" | "O" | "P" | "Q" | "R" | "S" | "T" | "U" | "V" | "W" | "X" | "Y" | "Z"
        | "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j" | "k" | "l" | "m"
        | "n" | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" | "w" | "x" | "y" | "z"
        | "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
        | "-" | "_" | "." | "~" | "&" ) as s ->
          Buffer.add_string b s
      | _ as s -> Printf.bprintf b "%%%2X" (Char.code (String.to_char s)))
    s;
  Buffer.contents b

let trim_start_while p s =
  let start = ref true in
  let b = Buffer.create (String.length s) in
  s
  |> String.reduce
       (fun _ s ->
         match s with
         | u when p u && !start -> ()
         | u when !start ->
             start := false;
             Buffer.add_string b u
         | u -> Buffer.add_string b u)
       ();
  Buffer.contents b

let underscore = "_"
let hyphen = "-"
let period = "."
let is_white_space s = Js.String.trim s |> String.length == 0
let is_alphabetic str = Js.Re.fromString "/^[a-zA-Z]*$/" |> Js.Re.test ~str
let is_hex_digit str = Js.Re.fromString "/[0-9a-fA-F]+/" |> Js.Re.test ~str

module Identifiers : sig
  type t

  val empty : t

  val touch : string -> t -> int * t
  (** Bump the frequency count for the given string. 
      It returns the previous count (before bumping) *)
end = struct
  module SMap = Map.Make (Stdlib.String)

  type t = int SMap.t

  let empty = SMap.empty
  let count s t = match SMap.find_opt s t with None -> 0 | Some x -> x
  let incr s t = SMap.add s (count s t + 1) t

  let touch s t =
    let count = count s t in
    (count, incr s t)
end

(* Based on pandoc algorithm to derive id's.
   See: https://pandoc.org/MANUAL.html#extension-auto_identifiers *)
let slugify s =
  let s = trim_start_while (fun s' -> not (is_alphabetic s')) s in
  let length = String.length s in
  let b = Buffer.create length in
  let last_is_ws = ref false in
  let add_to_buffer u =
    if !last_is_ws = true then begin
      Buffer.add_string b "-";
      last_is_ws := false
    end;
    Buffer.add_string b u
  in
  let fold () = function
    | u when is_white_space u && not !last_is_ws -> last_is_ws := true
    | u when is_white_space u && !last_is_ws -> ()
    | u ->
        if is_alphabetic u || is_hex_digit u then
          u |> Js.String.toLowerCase |> add_to_buffer;
        if u = underscore || u = hyphen || u = period then add_to_buffer u
  in
  String.reduce fold () s;
  Buffer.contents b

let to_plain_text t =
  let buf = Buffer.create 1024 in
  let rec go : _ inline -> unit = function
    | Concat (_, l) -> List.iter go l
    | Text (_, t) | Code (_, t) -> Buffer.add_string buf t
    | Emph (_, i)
    | Strong (_, i)
    | Link (_, { label = i; _ })
    | Image (_, { label = i; _ }) ->
        go i
    | Hard_break _ | Soft_break _ -> Buffer.add_char buf ' '
    | Html _ -> ()
  in
  go t;
  Buffer.contents buf

let nl = Raw "\n"

let rec url label destination title attrs =
  let attrs =
    match title with None -> attrs | Some title -> ("title", title) :: attrs
  in
  let attrs = ("href", escape_uri destination) :: attrs in
  elt Inline "a" attrs (Some (inline label))

and img label destination title attrs =
  let attrs =
    match title with None -> attrs | Some title -> ("title", title) :: attrs
  in
  let attrs =
    ("src", escape_uri destination) :: ("alt", to_plain_text label) :: attrs
  in
  elt Inline "img" attrs None

and inline = function
  | Ast.Impl.Concat (_, l) -> concat_map inline l
  | Text (_, t) -> text t
  | Emph (attr, il) -> elt Inline "em" attr (Some (inline il))
  | Strong (attr, il) -> elt Inline "strong" attr (Some (inline il))
  | Code (attr, s) -> elt Inline "code" attr (Some (text s))
  | Hard_break attr -> concat (elt Inline "br" attr None) nl
  | Soft_break _ -> nl
  | Html (_, body) -> raw body
  | Link (attr, { label; destination; title }) ->
      url label destination title attr
  | Image (attr, { label; destination; title }) ->
      img label destination title attr

let alignment_attributes = function
  | Default -> []
  | Left -> [ ("align", "left") ]
  | Right -> [ ("align", "right") ]
  | Centre -> [ ("align", "center") ]

let table_header headers =
  elt
    Table
    "thead"
    []
    (Some
       (elt
          Table
          "tr"
          []
          (Some
             (concat_map
                (fun (header, alignment) ->
                  let attrs = alignment_attributes alignment in
                  elt Block "th" attrs (Some (inline header)))
                headers))))

let table_body headers rows =
  elt
    Table
    "tbody"
    []
    (Some
       (concat_map
          (fun row ->
            elt
              Table
              "tr"
              []
              (Some
                 (concat_map2
                    (fun (_, alignment) cell ->
                      let attrs = alignment_attributes alignment in
                      elt Block "td" attrs (Some (inline cell)))
                    headers
                    row)))
          rows))

let rec block ~auto_identifiers = function
  | Blockquote (attr, q) ->
      elt
        Block
        "blockquote"
        attr
        (Some (concat nl (concat_map (block ~auto_identifiers) q)))
  | Paragraph (attr, md) -> elt Block "p" attr (Some (inline md))
  | List (attr, ty, sp, bl) ->
      let name = match ty with Ordered _ -> "ol" | Bullet _ -> "ul" in
      let attr =
        match ty with
        | Ordered (n, _) when n <> 1 -> ("start", string_of_int n) :: attr
        | _ -> attr
      in
      let li t =
        let block' t =
          match (t, sp) with
          | Paragraph (_, t), Tight -> concat (inline t) nl
          | _ -> block ~auto_identifiers t
        in
        let nl = if sp = Tight then Null else nl in
        elt Block "li" [] (Some (concat nl (concat_map block' t)))
      in
      elt Block name attr (Some (concat nl (concat_map li bl)))
  | Code_block (attr, label, code) ->
      let code_attr =
        if String.trim label = "" then []
        else [ ("class", "language-" ^ label) ]
      in
      let c = text code in
      elt Block "pre" attr (Some (elt Inline "code" code_attr (Some c)))
  | Thematic_break attr -> elt Block "hr" attr None
  | Html_block (_, body) -> raw body
  | Heading (attr, level, text) ->
      let name =
        match level with
        | 1 -> "h1"
        | 2 -> "h2"
        | 3 -> "h3"
        | 4 -> "h4"
        | 5 -> "h5"
        | 6 -> "h6"
        | _ -> "p"
      in
      elt Block name attr (Some (inline text))
  | Definition_list (attr, l) ->
      let f { term; defs } =
        concat
          (elt Block "dt" [] (Some (inline term)))
          (concat_map (fun s -> elt Block "dd" [] (Some (inline s))) defs)
      in
      elt Block "dl" attr (Some (concat_map f l))
  | Table (attr, headers, []) ->
      elt Table "table" attr (Some (table_header headers))
  | Table (attr, headers, rows) ->
      elt
        Table
        "table"
        attr
        (Some (concat (table_header headers) (table_body headers rows)))

let of_doc ?(auto_identifiers = true) doc =
  let identifiers = Identifiers.empty in
  let f identifiers = function
    | Heading (attr, level, text) ->
        let attr, identifiers =
          if (not auto_identifiers) || List.mem_assoc "id" attr then
            (attr, identifiers)
          else
            let id = slugify (to_plain_text text) in
            (* Default identifier if empty. It matches what pandoc does. *)
            let id = if id = "" then "section" else id in
            let count, identifiers = Identifiers.touch id identifiers in
            let id =
              if count = 0 then id else Printf.sprintf "%s-%i" id count
            in
            (("id", id) :: attr, identifiers)
        in
        (Heading (attr, level, text), identifiers)
    | _ as c -> (c, identifiers)
  in
  let html, _ =
    List.fold_left
      (fun (accu, ids) x ->
        let x', ids = f ids x in
        let el = concat accu (block ~auto_identifiers x') in
        (el, ids))
      (Null, identifiers)
      doc
  in
  html

let to_string t =
  let buf = Buffer.create 1024 in
  add_to_buffer buf t;
  Buffer.contents buf
