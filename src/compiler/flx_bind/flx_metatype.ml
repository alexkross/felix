(** Meta typing. *)

open Flx_print
open Flx_types
open Flx_btype
open Flx_exceptions

let rec metatype sym_table bsym_table rs sr term =
  (*
  print_endline ("Find Metatype  of: " ^
    string_of_btypecode bsym_table term);
  *)
  let t = metatype' sym_table bsym_table rs sr term in
  (*
  print_endline ("Metatype  of: " ^ string_of_btypecode bsym_table term ^
    " is " ^ sbt bsym_table t);
  print_endline "Done";
  *)
  t

and metatype' sym_table bsym_table rs sr term =
  let st t = sbt bsym_table t in
  let mt t = metatype' sym_table bsym_table rs sr t in
(*
print_endline ("Metatyping term " ^ st term);
*)
  match term with

  | BTYP_type_function (a,b,c) ->
    let ps = List.map snd a in
    let argt =
      match ps with
      | [x] -> x
      | _ -> btyp_tuple ps
    in
      let rt = metatype sym_table bsym_table rs sr c in
      if b<>rt
      then
        clierr sr
        (
          "In abstraction\n" ^
          st term ^
          "\nFunction body metatype \n"^
          st rt^
          "\ndoesn't agree with declared type \n" ^
          st b
        )
      else btyp_function (argt,b)

  | BTYP_type_tuple ts ->
    btyp_tuple (List.map mt ts)

  | BTYP_type_apply (a,b) ->
    begin
      let ta = mt a
      and tb = mt b
      in match ta with
      | BTYP_function (x,y) ->
        if x = tb then y
        else
          clierr sr (
            "Metatype error: type term " ^
             st term ^
            "\nfunction argument wrong metatype, expected:\n" ^
            st  x ^
            "\nbut got:\n" ^
            st tb
          )

      | _ -> clierr sr
        (
          "Metatype error: function required for LHS of application:\n"^
          sbt bsym_table term ^
          ", got metatype:\n" ^
          sbt bsym_table ta
        )
    end
  | BTYP_type_var (i,mt) ->
    (*
    print_endline ("Type variable " ^ si i^ " has encoded meta type " ^
      sbt bsym_table mt);
    (
      try
        let symdef = Flx_sym_table.find sym_table i in begin match symdef with
        | {symdef=SYMDEF_typevar mt} ->
            print_endline ("Table shows metatype is " ^ string_of_typecode mt);
        | _ -> print_endline "Type variable isn't a type variable?"
        end
      with Not_found ->
        print_endline "Cannot find type variable in symbol table"
    );
    *)
    mt

  | BTYP_type i -> btyp_type (i+1)
  | BTYP_inst (index,ts) ->
      let sym =
        try Flx_sym_table.find sym_table index with Not_found ->
          failwith ("[metatype'] can't find type instance index " ^
            string_of_bid index)
      in

      (* this is hacked: we should really bind the types and take the metatype
       * of them but we don't have access to the bind type routine due to module
       * factoring. we could pass in the bind-type routine as an argument.
       * yuck.  *)
      begin match sym.Flx_sym.symdef with
      | SYMDEF_nonconst_ctor (_,ut,_,_,argt) ->
          btyp_function (btyp_type 0,btyp_type 0)
      | SYMDEF_const_ctor (_,t,_,_) -> btyp_type 0
      | SYMDEF_abs _ -> btyp_type 0
      | SYMDEF_newtype _ -> btyp_type 0 
(*
          clierr sr ("Unexpected argument to metatype, newtype : " ^
            sbt bsym_table term)
*)
      | SYMDEF_struct _ 
      | SYMDEF_cstruct _ -> btyp_type 0
(*
          clierr sr ("Unexpected argument to metatype, struct or cstruct : " ^
            sbt bsym_table term)
*)
      | SYMDEF_type_alias _ -> 
          clierr sr ("Unexpected argument to metatype, type alias: " ^
            sbt bsym_table term)

      | _ ->
          clierr sr ("Unexpected argument to metatype: " ^
            sbt bsym_table term)
      end

  (* Ordinary type expressions *)
  | BTYP_cfunction _
  | BTYP_function _
  | BTYP_pointer _
  | BTYP_variant _
  | BTYP_record _
  | BTYP_sum _
  | BTYP_array _
  | BTYP_tuple _
  | BTYP_void

  | BTYP_int
  | BTYP_intersect _
  | BTYP_polyrecord (_, _)
  | BTYP_type_match (_, _)
  | BTYP_tuple_cons (_, _)
  | BTYP_unitsum _ -> btyp_type 0
  | BTYP_fix (i,mt) -> 
(*
    let si i = string_of_int i in
    let catmap sep f ls = String.concat sep (List.map f ls) in
    print_endline ("Meta type of fix point " ^ si i ^ ", type-alias-fixlist = ");
    print_endline (catmap ","  (fun (idx,level) -> "Index=" ^ si idx ^ " level = " ^ si level) (rs.type_alias_fixlist));
    print_endline "Idx fixlist is:";
    print_endline (catmap ","  (fun (idx) -> "Index=" ^ si idx ) (rs.idx_fixlist));
    print_endline "Expr fixlist is:";
    print_endline (catmap ","  (fun (e,d) -> "Expr=" ^ string_of_expr e ^ " depth=" ^ si d ) (rs.expr_fixlist));
    print_endline "As fixlist is:";
    print_endline (catmap ","  (fun (s,level) -> "as variable =" ^ s ^ " level = " ^ si level) (rs.as_fixlist));
*)
    mt
(*
  | _ ->
(*
    print_endline ("Questionable meta typing of term: " ^
      sbt bsym_table term);
*)
    btyp_type 0 (* THIS ISN'T RIGHT *)

*)

  | BTYP_label
  | BTYP_type_set _
  | BTYP_type_set_union _
  | BTYP_type_set_intersection _
  | BTYP_none
    ->
    clierr sr ("No meta type for type-like term " ^ sbt bsym_table term)


