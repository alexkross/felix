
open Flx_util
open Flx_list
open Flx_types
open Flx_btype
open Flx_bexpr
open Flx_bbdcl
open Flx_mtypes2
open Flx_name
open Flx_unify
open Flx_typing
open List
open Flx_print
open Flx_exceptions
open Flx_maps
open Flx_cal_type_offsets
open Flx_gen_shape
open Flx_findvars

let is_instantiated syms i ts = Hashtbl.mem syms.instances (i,ts)

let gen_fun_offsets s syms bsym_table index vs ps ret ts instance props last_ptr_map : unit =
  let vars =  (find_references syms bsym_table index ts) in
  let vars = filter (fun (i, _) -> is_instantiated syms i ts) vars in
  let name = cpp_instance_name syms bsym_table index ts in
  let display = Flx_display.get_display_list bsym_table index in
  let offsets =
    (if mem `Requires_ptf props then
    ["FLX_EAT_PTF(offsetof(" ^ name ^ ",ptf)comma)"]
    else []
    )
    @
    (match ret with
      | BTYP_void -> [ ("offsetof(" ^ name ^ ",p_svc),");("offsetof(" ^ name ^ ",_caller),")    ]
      | _ -> []
    )
    @
    map
    (fun (didx, vslen) ->
    let dptr = "ptr" ^ cpp_instance_name syms bsym_table didx (list_prefix ts vslen) in
    "offsetof("^name^","^dptr^"),"
    )
    display
    @
    concat
    (
      map
      (fun (idx,typ)->
        let mem = cpp_instance_name syms bsym_table idx ts in
        let offsets = get_offsets syms bsym_table typ in
        map
        (fun offset ->
          "offsetof("^name^","^mem^")+" ^ offset
        )
        offsets
      )
      vars
    )
  in
  let n = length offsets in
  bcat s
  (
    "\n//OFFSETS for "^
    (match ret with BTYP_void -> "procedure " | _ -> "function ") ^
    name ^ "\n"
  );
  gen_offset_data s n name offsets true false props None last_ptr_map

let gen_all_fun_shapes scan s syms bsym_table last_ptr_map =

  (* Make a shape for every non-C style function with the property `Heap_closure *)
  (* print_endline "Function and procedure offsets"; *)
  Hashtbl.iter begin fun (index,ts) instance ->
    let bsym =
      try Flx_bsym_table.find bsym_table index
      with Not_found ->
        failwith ("[gen_offset_tables] can't find index " ^ string_of_bid index)
    in
    (*
    print_endline ("Offsets for " ^ id ^ "<"^ si index ^">["^catmap "," (sbt bsym_table) ts ^"]");
    *)
    match Flx_bsym.bbdcl bsym with
    | BBDCL_fun (props,vs,ps,ret,exes) ->
        scan exes;
        if mem `Cfun props then () else
        if mem `Heap_closure props then
          gen_fun_offsets
            s
            syms
            bsym_table
            index
            vs
            ps
            ret
            ts
            instance
            props
            last_ptr_map
    | _ -> ()
  end syms.instances;

