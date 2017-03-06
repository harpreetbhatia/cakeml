open preamble astTheory jsonTheory backend_commonTheory;
open modLangTheory;

val _ = new_theory"presLang";

(*
* presLang is a presentation language, encompassing many intermediate languages
* of the compiler, adopting their constructors. The purpose of presLang is to be
* an intermediate representation between an intermediate language of the
* compiler and JSON. By translating an intermediate language to presLang, it can
* be given a JSON representation by calling pres_to_json on the presLang
* representation. presLang has no semantics, as it is never evaluated, and may
* therefore mix operators, declarations, patterns and expressions.
*)

(* Special operator wrapper for presLang *)
val _ = Datatype`
  op =
    Ast ast$op`;

val _ = Datatype`
  exp =
    (* An entire program. Is divided into any number of top level prompts. *)
    | Prog (exp(*prompt*) list)
    | Prompt (modN option) (exp(*dec*) list)
    (* Declarations *)
    | Dlet num exp(*exp*)
    | Dletrec ((varN # varN # exp(*exp*)) list)
    | Dtype (modN list) type_def
    | Dexn (modN list) conN (t list)
    (* Patterns *)
    | Pvar varN
    | Plit lit
    | Pcon (((modN, conN) id) option) (exp(*pat*) list)
    | Pref exp(*pat*)
    | Ptannot exp(*pat*) t
    (* Expressions *)
    | Raise tra exp
    | Handle tra exp ((exp(*pat*) # exp) list)
    | Var_local tra varN
    | Var_global tra num
    | Lit tra lit
      (* Constructor application.
       A Nothing constructor indicates a tuple pattern. *)
    | Con tra (((modN, conN) id) option) (exp list)
      (* Application of a primitive operator to arguments.
       Includes function application. *)
    | App tra op (exp list)
    | Fun tra varN exp
      (* Logical operations (and, or) *)
    | Log tra lop exp exp
    | If tra exp exp exp
      (* Pattern matching *)
    | Mat tra exp ((exp(*pat*) # exp) list)
      (* A let expression
         A Nothing value for the binding indicates that this is a
         sequencing expression, that is: (e1; e2). *)
    | Let tra (varN option) exp exp
      (* Local definition of (potentially) mutually recursive
         functions.
         The first varN is the function's name, and the second varN
         is its parameter. *)
    | Letrec tra ((varN # varN # exp) list) exp`;

(* Functions for converting intermediate languages to presLang. *)

(* modLang *)

val mod_to_pres_pat_def = tDefine "mod_to_pres_pat"`
  mod_to_pres_pat p =
    case p of
       | ast$Pvar varN => presLang$Pvar varN
       | Plit lit => Plit lit
       | Pcon id pats => Pcon id (MAP mod_to_pres_pat pats)
       | Pref pat => Pref (mod_to_pres_pat pat)
       (* Won't happen, these are removed in compilation from source to mod. *)
       | Ptannot pat t => Ptannot (mod_to_pres_pat pat) t`
   cheat;

val mod_to_pres_exp_def = tDefine"mod_to_pres_exp"`
  (mod_to_pres_exp (modLang$Raise tra exp) = presLang$Raise tra (mod_to_pres_exp exp))
  /\
  (mod_to_pres_exp (Handle tra exp pes) =
    Handle tra (mod_to_pres_exp exp) (mod_to_pres_pes pes))
  /\
  (mod_to_pres_exp (Lit tra lit) = Lit tra lit)
  /\
  (mod_to_pres_exp (Con tra id_opt exps) = Con tra id_opt (MAP mod_to_pres_exp exps))
  /\
  (mod_to_pres_exp (Var_local tra varN) = Var_local tra varN)
  /\
  (mod_to_pres_exp (Var_global tra num) =  Var_global tra num)
  /\
  (mod_to_pres_exp (Fun tra varN exp) =  Fun tra varN (mod_to_pres_exp exp))
  /\
  (mod_to_pres_exp (App tra op exps) =  App tra (Ast op) (MAP mod_to_pres_exp exps))
  /\
  (mod_to_pres_exp (If tra exp1 exp2 exp3) =
    If tra (mod_to_pres_exp exp1) (mod_to_pres_exp exp2) (mod_to_pres_exp exp3))
  /\
  (mod_to_pres_exp (Mat tra exp pes) =
    Mat tra (mod_to_pres_exp exp) (mod_to_pres_pes pes))
  /\
  (mod_to_pres_exp (Let tra varN_opt exp1 exp2) =
    Let tra varN_opt (mod_to_pres_exp exp1) (mod_to_pres_exp exp2))
  /\
  (mod_to_pres_exp (Letrec tra funs exp) =
    Letrec tra
          (MAP (\(v1,v2,e).(v1,v2,mod_to_pres_exp e)) funs)
          (mod_to_pres_exp exp))
  /\
  (* Pattern-expression pairs *)
  (mod_to_pres_pes [] = [])
  /\
  (mod_to_pres_pes ((p,e)::pes) =
    (mod_to_pres_pat p, mod_to_pres_exp e)::mod_to_pres_pes pes)`
  cheat;

val mod_to_pres_dec_def = Define`
  mod_to_pres_dec d =
    case d of
       | modLang$Dlet num exp => presLang$Dlet num (mod_to_pres_exp exp)
       | Dletrec funs => Dletrec (MAP (\(v1,v2,e). (v1,v2,mod_to_pres_exp e)) funs)
       | Dtype mods type_def => Dtype mods type_def
       | Dexn mods conN ts => Dexn mods conN ts`;

val mod_to_pres_prompt_def = Define`
  mod_to_pres_prompt (Prompt modN decs) =
    Prompt modN (MAP mod_to_pres_dec decs)`;

val mod_to_pres_def = Define`
  mod_to_pres prompts = Prog (MAP mod_to_pres_prompt prompts)`;

(* pres_to_json *)
val lit_to_value_def = Define`
  (lit_to_value (IntLit i) = Int i)
  /\
  (lit_to_value (Char c) = String (c::""))
  /\
  (lit_to_value (StrLit s) = String s)`;

(* Create a new json$Object with keys and values as in the tuples. Every object
* has constructor name field, cons *)
val new_obj_def = Define`
  new_obj cons fields = json$Object (("cons", String cons)::fields)`;
(* TODO: Define num_to_json *)
val num_to_json_def = Define`
  num_to_json n = Int (int_of_num n)`;
(* TODO: Define tdef_to_json *)
val tdef_to_json_def = Define`
  tdef_to_json td = Null`;

(* TODO: Define trace_to_json *)
val trace_to_json_def = Define`
  trace_to_json _ = Null`;

(* TODO: Define t_to_json*)
val t_to_json_def = Define`
  t_to_json t = Null`;

(* TODO: Define op_to_json*)
val op_to_json_def = Define`
  op_to_json op = Null`;

(* TODO: Define log_to_json*)
val log_to_json_def = Define`
  log_to_json l = Null`;
val id_to_list_def = Define`
  id_to_list i = case i of
                      | Long modN i' => modN::id_to_list i'
                      | Short conN => [conN]`;

val id_to_object_def = Define`
    id_to_object ids = Array (MAP String (id_to_list ids))`

val lit_to_json_def = Define`
  (lit_to_json (IntLit i) = ("IntLit", Int i))
  /\
  (lit_to_json (Char c) = ("Char", String (c::"")))
  /\
  (lit_to_json (StrLit s) = ("StrLit", String s))
  /\
  (lit_to_json (Word8 w) = ("word8", String (word_to_hex_string w)))
  /\
  (lit_to_json (Word64 w) = ("word64", String (word_to_hex_string w)))`

val option_to_json_def = Define`
  (option_to_json opt = case opt of
                      | NONE => Null
                      | SOME opt' => String opt')`
(* Takes a presLang$exp and produces json$obj that mimics its structure. *)
val pres_to_json_def = tDefine"pres_to_json"`
  (* Top level *)
  (pres_to_json (presLang$Prog tops) =
    let tops' = Array (MAP pres_to_json tops) in
      new_obj "Prog" [("tops", tops')])
  /\
  (pres_to_json (Prompt modN decs) =
    let decs' = Array (MAP pres_to_json decs) in
    let modN' = option_to_json modN in
      new_obj "Prompt" [("modN", modN'); ("decs", decs')])
  /\
  (pres_to_json (Dlet num exp) =
      new_obj "Dlet" [("num", num_to_json num); ("exp", pres_to_json exp)])
  /\
  (pres_to_json (Dletrec lst) =
    let fields = Array (MAP (\(v1,v2,exp) . Object [("var1",String v1); ("var2",String v2); ("exp", pres_to_json exp)]) lst) in
      new_obj "Dletrec" [("exps",fields)])
  /\
  (pres_to_json (Dtype modNs tDef) =
    let modNs' = Array (MAP String modNs) in
      new_obj "Dtype" [("modNs", modNs'); ("tDef", tdef_to_json tDef)])
  /\
  (pres_to_json (Dexn modNs conN ts) =
    let modNs' = Array (MAP String modNs) in
    let ts' = Array (MAP t_to_json ts) in
      new_obj "Dexn" [("modNs", modNs'); ("con", String conN); ("ts", ts')])
  /\
  (pres_to_json (Pvar varN) =
      new_obj "Pvar" [("pat", Object[("var",String varN)])])
  /\
  (pres_to_json (Plit lit) =
      new_obj "Plit" [("pat", Object[lit_to_json lit])])
  /\
  (pres_to_json (Pcon optTup exps) =
    let exps' = ("pat", Array (MAP pres_to_json exps)) in
    let ids' = case optTup of
                  | NONE => ("modscon", Null)
                  | SOME optUp' => ("modscon", (id_to_object optUp')) in

      new_obj "Pcon" [ids';exps'])
  /\
  (pres_to_json (Pref exp) =
      new_obj "Pref" [("pat", pres_to_json exp)])
  /\
  (pres_to_json (Ptannot exp t) =
      new_obj "Ptannot" [("pat", pres_to_json exp);("t", t_to_json t)])
  /\
  (pres_to_json (Raise tra exp) =
      new_obj "Raise" [("tra", trace_to_json tra);("exp", pres_to_json exp)])
  /\
  (pres_to_json (Handle tra exp expsTup) =
    let expsTup' = Array (MAP(\(e1, e2) . Object[("pat", pres_to_json e1);("exp",
    pres_to_json e2)])
    expsTup) in
      new_obj "Handle" [("tra", trace_to_json tra);("exp", pres_to_json exp);("exps", expsTup')])
  /\
  (pres_to_json (Var_local tra varN) =
      new_obj "Var_local" [("tra", trace_to_json tra);("var", String varN)])
  /\
  (pres_to_json (Var_global tra num) =
      new_obj "Var_global" [("tra", trace_to_json tra);("num", num_to_json num)])
  /\
  (pres_to_json (Lit tra lit) =
      new_obj "Lit" [("tra", trace_to_json tra);lit_to_json lit])
  /\
  (pres_to_json (Con tra optTup exps) =
    let exps' = ("exps", Array (MAP pres_to_json exps)) in
    let ids' = case optTup of
                  | NONE => ("modscon", Null)
                  | SOME optUp' => ("modscon", (id_to_object optUp')) in
      new_obj "Con" [("tra", trace_to_json tra);ids';exps'])
  /\
  (pres_to_json (App tra op exps) =
    let exps' = ("exps", Array (MAP pres_to_json exps)) in
      new_obj "App" [("tra", trace_to_json tra);("op", op_to_json op);exps'])
  /\
  (pres_to_json (Fun tra varN exp) =
      new_obj "Fun" [("tra", trace_to_json tra);("var", String varN);("exp",
      pres_to_json exp)])
  /\
  (pres_to_json (Log tra log exp1 exp2) =
      new_obj "Log" [("tra", trace_to_json tra);("log", log_to_json
      log);("exp1", pres_to_json exp1);("exp2", pres_to_json exp2)])
  /\
  (pres_to_json (If tra exp1 exp2 exp3) =
      new_obj "If" [("tra", trace_to_json tra);("exp1", pres_to_json exp1);("exp2",
      pres_to_json exp2);("exp3", pres_to_json exp3)])
  /\
  (pres_to_json (Mat tra exp expsTup) =
    let expsTup' = Array (MAP(\(e1, e2) . Object[("pat", pres_to_json e1);("exp",
    pres_to_json e2)]) expsTup) in
      new_obj "Mat" [("tra", trace_to_json tra);("exp", pres_to_json
      exp);("exps",expsTup')])
  /\
  (pres_to_json (Let tra varN exp1 exp2) =
    let varN' = option_to_json varN in
      new_obj "Let" [("tra", trace_to_json tra);("var", varN');("exp1", pres_to_json
      exp1);("exp2", pres_to_json exp2)])
  /\
  (*TODO: Decide on whether "varsexp" is a reasonable name, probably not *)
  (pres_to_json (Letrec tra varexpTup exp) =
    let varexpTup' = Array (MAP (\(v1,v2,e) . Object [("var1", String
    v1);("var2", String v2);("exp", pres_to_json e)]) varexpTup) in
      new_obj "Letrec" [("tra", trace_to_json tra);("varsexp",
      varexpTup');("exp", pres_to_json exp)])
  /\
  (pres_to_json _ = Null)`
  cheat;

val _ = export_theory();
