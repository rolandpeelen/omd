(lang dune 3.8)
(name omd)
(using melange 0.1)
(version 2.0.0~melange)

(cram enable)


(generate_opam_files)

(license ISC)
(authors "Philippe Wang <philippe.wang@gmail.com>"
         "Nicolás Ojeda Bär <n.oje.bar@gmail.com>")
(maintainers "Shon Feder <shon.feder@gmail.com>"
             "Raphael Sousa Santos <@sonologico>")
(source (github ocaml/omd))

(package
 (name omd)
 (synopsis "A Markdown frontend in pure OCaml")
 (description
  "This Markdown library is implemented using only pure OCaml (including
I/O operations provided by the standard OCaml compiler distribution).
OMD is meant to be as faithful as possible to the original Markdown.
Additionally, OMD implements a few Github markdown features, an
extension mechanism, and some other features. Note that the opam
package installs both the OMD library and the command line tool `omd`.")
 (tags (org:ocamllabs org:mirage))
 (depends
  (dune (>= 3.14))
  (ocaml (>= 5.1))
  (melange (>= 3.0.0))
  (dune-build-info (>= 3.14))
  (ocamlformat :with-dev)
  (ppx_expect :with-test)))
