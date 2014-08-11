(*Generated by Lem from modLang.lem.*)
open HolKernel Parse boolLib bossLib;
open lem_pervasivesTheory libTheory astTheory semanticPrimitivesTheory lem_list_extraTheory bigStepTheory;

val _ = numLib.prefer_num();



val _ = new_theory "modLang"

(* The first intermediate language modLang. Removes modules, and introduces
 * special variable references for referring to top-level bindings.  Also
 * removes andalso and orelse and replaces them with if. 
 *
 * The AST of modLang differs from the source language by having two variable
 * reference forms, one to reference local bindings (still by name) and one to
 * reference global bindings (by index). At the top level, modules are gone.
 * However a Prompt is introduced to group declarations whose bindings should
 * all be installed by the REPL only if none of them encounters an exception
 * (one of the functions that modules perform in the source language).
 * Top-level lets and letrecs no longer bind names (or have patterns), and the
 * lets come with just a number indicating how many bindings to install in the
 * global environment.
 * 
 * The values of modLang differ in that the closures do not contain a module
 * environment.
 *
 * The semantics of modLang differ in that there is no module environment menv, nor
 * are top-level bindings added to the normal env, thus when a closure is
 * created, only locals bindings are put into it. There is a global environment
 * genv, which is just a list of the top-level bindings seen so far, with the
 * older bindings nearer the head. Global variable reference expressions simply
 * index into global environment. Top-level let rec declarations evaluate to
 * closures, rather than to recursive closures, since the recursion can be
 * handled through the genv. The expressions bound to top-level lets must
 * evaluate to a tuple with exactly as many things in it as the number of
 * bindings that the let will bind.
 *
 * The translator to modLang keeps two mappings, one mapping module paths to
 * indices into the genv, and the other mapping top-level non-module bindings
 * to genv indices. All variable references are replaced with global references
 * to the genv index if they are in the mappings. This includes top-level
 * letrec names which are all put into the mapping before translating any of
 * the let rec functions. This enables the semantics of let rec to just create
 * Closures rather than Recclosures.
 *
 * *)

(*open import Pervasives*)
(*open import Lib*)
(*open import Ast*)
(*open import SemanticPrimitives*)
(*open import List_extra*)
(*open import BigStep*)

val _ = Hol_datatype `
 exp_i1 =
    Raise_i1 of exp_i1
  | Handle_i1 of exp_i1 => (pat # exp_i1) list
  | Lit_i1 of lit
  | Con_i1 of  ( conN id)option => exp_i1 list
  | Var_local_i1 of varN
  | Var_global_i1 of num
  | Fun_i1 of varN => exp_i1
  | App_i1 of op => exp_i1 list
  | If_i1 of exp_i1 => exp_i1 => exp_i1
  | Mat_i1 of exp_i1 => (pat # exp_i1) list
  | Let_i1 of  varN option => exp_i1 => exp_i1
  | Letrec_i1 of (varN # varN # exp_i1) list => exp_i1`;


val _ = Hol_datatype `
 dec_i1 =
    (* The nat is how many top-level variables this declaration binds *)
    Dlet_i1 of num => exp_i1
  | Dletrec_i1 of (varN # varN # exp_i1) list
  | Dtype_i1 of  modN option => type_def
  | Dexn_i1 of  modN option => conN => t list`;


(* A prompt is a list of declarations that must execute `atomically'; it
 * corresponds to a module body in the source language. If any of the
 * declarations results in an exception reaching the prompt's top level, none
 * of the declaration binding are installed. The module name is book-keeping
 * for the constructors *)
val _ = Hol_datatype `
 prompt_i1 =
    Prompt_i1 of  modN option => dec_i1 list`;


val _ = Hol_datatype `
 v_i1 =
    Litv_i1 of lit
  | Conv_i1 of  (conN # tid_or_exn)option => v_i1 list 
  | Closure_i1 of (envC # (varN, v_i1) env) => varN => exp_i1
  | Recclosure_i1 of (envC # (varN, v_i1) env) => (varN # varN # exp_i1) list => varN
  | Loc_i1 of num
  | Vectorv_i1 of v_i1 list`;


(*val exp_to_i1 : map modN (map varN nat) -> map varN nat -> exp -> exp_i1*)
(*val exps_to_i1 : map modN (map varN nat) -> map varN nat -> list exp -> list exp_i1*)
(*val pat_exp_to_i1 : map modN (map varN nat) -> map varN nat -> list (pat * exp) -> list (pat * exp_i1)*)
(*val funs_to_i1 : map modN (map varN nat) -> map varN nat -> list (varN * varN * exp) -> list (varN * varN * exp_i1)*)
 val exp_to_i1_defn = Hol_defn "exp_to_i1" `
 
(exp_to_i1 menv env (Raise e) =  
 (Raise_i1 (exp_to_i1 menv env e)))
/\
(exp_to_i1 menv env (Handle e pes) =  
 (Handle_i1 (exp_to_i1 menv env e) (pat_exp_to_i1 menv env pes)))
/\
(exp_to_i1 menv env (Lit l) =  
 (Lit_i1 l)) 
/\
(exp_to_i1 menv env (Con cn es) =  
 (Con_i1 cn (exps_to_i1 menv env es)))
/\
(exp_to_i1 menv env (Var (Short x)) =  
 ((case FLOOKUP env x of
      NONE => Var_local_i1 x
    | SOME n => Var_global_i1 n
  )))
/\
(exp_to_i1 menv env (Var (Long mn x)) =  
((case FLOOKUP menv mn of
      NONE => Var_global_i1( 0) (* Can't happen *)
    | SOME env' =>
        (case FLOOKUP env' x of
            NONE => Var_global_i1( 0) (* Can't happen *)
          | SOME n => Var_global_i1 n
        )
  )))
/\
(exp_to_i1 menv env (Fun x e) =  
(Fun_i1 x (exp_to_i1 menv (env \\ x) e))) 
/\
(exp_to_i1 menv env (App op es) =  
(App_i1 op (exps_to_i1 menv env es)))
/\
(exp_to_i1 menv env (Log lop e1 e2) =  
((case lop of
      And => If_i1 (exp_to_i1 menv env e1) (exp_to_i1 menv env e2) (Lit_i1 (Bool F))
    | Or => If_i1 (exp_to_i1 menv env e1) (Lit_i1 (Bool T)) (exp_to_i1 menv env e2)
  )))
/\
(exp_to_i1 menv env (If e1 e2 e3) =  
(If_i1 (exp_to_i1 menv env e1) (exp_to_i1 menv env e2) (exp_to_i1 menv env e3)))
/\
(exp_to_i1 menv env (Mat e pes) =  
(Mat_i1 (exp_to_i1 menv env e) (pat_exp_to_i1 menv env pes)))
/\
(exp_to_i1 menv env (Let (SOME x) e1 e2) =  
(Let_i1 (SOME x) (exp_to_i1 menv env e1) (exp_to_i1 menv (env \\ x) e2)))
/\
(exp_to_i1 menv env (Let NONE e1 e2) =  
(Let_i1 NONE (exp_to_i1 menv env e1) (exp_to_i1 menv env e2)))
/\
(exp_to_i1 menv env (Letrec funs e) =  
(let fun_names = (MAP (\ (f,x,e) .  f) funs) in
    Letrec_i1 (funs_to_i1 menv (FOLDR (\ k m. m \\ k) env fun_names) funs) 
              (exp_to_i1 menv (FOLDR (\ k m. m \\ k) env fun_names) e)))
/\
(exps_to_i1 menv env [] = ([]))
/\
(exps_to_i1 menv env (e::es) =  
(exp_to_i1 menv env e :: exps_to_i1 menv env es))
/\
(pat_exp_to_i1 menv env [] = ([]))
/\
(pat_exp_to_i1 menv env ((p,e)::pes) =  
((p, exp_to_i1 menv (FOLDR (\ k m. m \\ k) env (pat_bindings p [])) e) ::
  pat_exp_to_i1 menv env pes))
/\
(funs_to_i1 menv env [] = ([]))
/\
(funs_to_i1 menv env ((f,x,e)::funs) =  
((f,x,exp_to_i1 menv (env \\ x) e) :: funs_to_i1 menv env funs))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn exp_to_i1_defn;

(*val alloc_defs : nat -> list varN -> list (varN * nat)*)
 val _ = Define `
 (alloc_defs next [] = ([])) 
/\ (alloc_defs next (x::xs) =  
((x,next) :: alloc_defs (next + 1) xs))`;


(*val dec_to_i1 : nat -> maybe modN -> map modN (map varN nat) -> map varN nat -> dec -> nat * env varN nat * dec_i1*)
val _ = Define `
 (dec_to_i1 next mn menv env d =  
((case d of
      Dlet p e =>
        let e' = (exp_to_i1 menv env e) in
        let xs = (REVERSE (pat_bindings p [])) in
        let l = (LENGTH xs) in
          ((next + l), 
           alloc_defs next xs,
           Dlet_i1 l (Mat_i1 e' [(p, Con_i1 NONE (MAP Var_local_i1 xs))]))
    | Dletrec funs =>
        let fun_names = (REVERSE (MAP (\ (f,x,e) .  f) funs)) in
        let env' = (alloc_defs next fun_names) in
          ((next + LENGTH fun_names),
           env',
           Dletrec_i1 (funs_to_i1 menv (FOLDL (\ env (k,v) . env |+ (k, v)) env env') (REVERSE funs)))
    | Dtype type_def =>
        (next, [], Dtype_i1 mn type_def)
    | Dtabbrev tvs tn t =>
        (next, [], Dtype_i1 mn [])
    | Dexn cn ts =>
        (next, [], Dexn_i1 mn cn ts)
  )))`;


(*val decs_to_i1 : nat -> maybe modN -> map modN (map varN nat) -> map varN nat -> list dec -> nat * env varN nat * list dec_i1*)
 val decs_to_i1_defn = Hol_defn "decs_to_i1" `
 
(decs_to_i1 next mn menv env [] = (next, emp, []))
/\
(decs_to_i1 next mn menv env (d::ds) =  
(let (next1, new_env1, d') = (dec_to_i1 next mn menv env d) in
  let (next2, new_env2, ds') =    
 (decs_to_i1 next1 mn menv (FOLDL (\ env (k,v) . env |+ (k, v)) env new_env1) ds) 
  in
    (next2, (new_env1 ++ new_env2), (d'::ds'))))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn decs_to_i1_defn;

(*val top_to_i1 : nat -> map modN (map varN nat) -> map varN nat -> top -> nat * map modN (map varN nat) * map varN nat * prompt_i1*)
val _ = Define `
 (top_to_i1 next menv env top =  
((case top of
      Tdec d =>
        let (next', new_env, d') = (dec_to_i1 next NONE menv env d) in
          (next', menv, FOLDL (\ env (k,v) . env |+ (k, v)) env new_env, Prompt_i1 NONE [d'])
    | Tmod mn specs ds =>
        let (next', new_env, ds') = (decs_to_i1 next (SOME mn) menv env ds) in
          (next',menv |+ (mn, (FOLDL (\ env (k,v) . env |+ (k, v)) FEMPTY new_env)), env, Prompt_i1 (SOME mn) ds')
  )))`;


(*val prog_to_i1 : nat -> map modN (map varN nat) -> map varN nat -> list top -> nat * map modN (map varN nat) * map varN nat * list prompt_i1*)
 val _ = Define `
 
(prog_to_i1 next menv env [] = (next, menv, env, []))
/\ 
(prog_to_i1 next menv env (p::ps) =  
 (let (next', menv', env',p') = (top_to_i1 next menv env p) in
  let (next'', menv'', env'',ps') = (prog_to_i1 next' menv' env' ps) in
    (next'',menv'',env'',(p'::ps'))))`;


val _ = type_abbrev( "all_env_i1" , ``: ( ( v_i1 option)list # envC # (varN, v_i1) env)``);

val _ = Define `
 (all_env_i1_to_genv (genv,cenv,env) = genv)`;

val _ = Define `
 (all_env_i1_to_cenv (genv,cenv,env) = cenv)`;

val _ = Define `
 (all_env_i1_to_env (genv,cenv,env) = env)`;

          
(*val build_conv_i1 : envC -> maybe (id conN) -> list v_i1 -> maybe v_i1*)
val _ = Define `
 (build_conv_i1 envC cn vs =  
((case cn of
      NONE => 
        SOME (Conv_i1 NONE vs)
    | SOME id => 
        (case lookup_con_id id envC of
            NONE => NONE
          | SOME (len,t) => SOME (Conv_i1 (SOME (id_to_n id, t)) vs)
        )
  )))`;


(*val build_rec_env_i1 : list (varN * varN * exp_i1) -> (envC * env varN v_i1) -> env varN v_i1 -> env varN v_i1*)
val _ = Define `
 (build_rec_env_i1 funs cl_env add_to_env =  
(FOLDR 
    (\ (f,x,e) env' .  bind f (Recclosure_i1 cl_env funs f) env') 
    add_to_env 
    funs))`;


(*val do_eq_i1 : v_i1 -> v_i1 -> eq_result*)
 val do_eq_i1_defn = Hol_defn "do_eq_i1" `

(do_eq_i1 (Litv_i1 l1) (Litv_i1 l2) =  
(if lit_same_type l1 l2 then Eq_val (l1 = l2)
  else Eq_type_error))
/\
(do_eq_i1 (Loc_i1 l1) (Loc_i1 l2) = (Eq_val (l1 = l2)))
/\
(do_eq_i1 (Conv_i1 cn1 vs1) (Conv_i1 cn2 vs2) =  
(if (cn1 = cn2) /\ (LENGTH vs1 = LENGTH vs2) then
    do_eq_list_i1 vs1 vs2
  else
    Eq_val F))
/\
(do_eq_i1 (Vectorv_i1 vs1) (Vectorv_i1 vs2) =  
(if LENGTH vs1 = LENGTH vs2 then
    do_eq_list_i1 vs1 vs2
  else
    Eq_val F))
/\
(do_eq_i1 (Closure_i1 _ _ _) (Closure_i1 _ _ _) = Eq_closure)
/\
(do_eq_i1 (Closure_i1 _ _ _) (Recclosure_i1 _ _ _) = Eq_closure)
/\
(do_eq_i1 (Recclosure_i1 _ _ _) (Closure_i1 _ _ _) = Eq_closure)
/\
(do_eq_i1 (Recclosure_i1 _ _ _) (Recclosure_i1 _ _ _) = Eq_closure)
/\
(do_eq_i1 _ _ = Eq_type_error)
/\
(do_eq_list_i1 [] [] = (Eq_val T))
/\
(do_eq_list_i1 (v1::vs1) (v2::vs2) =  
 ((case do_eq_i1 v1 v2 of
      Eq_closure => Eq_closure
    | Eq_type_error => Eq_type_error
    | Eq_val r => 
        if ~ r then
          Eq_val F
        else
          do_eq_list_i1 vs1 vs2
  )))
/\
(do_eq_list_i1 _ _ = (Eq_val F))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn do_eq_i1_defn;

(*val prim_exn_i1 : conN -> v_i1*)
val _ = Define `
 (prim_exn_i1 cn = (Conv_i1 (SOME (cn, TypeExn (Short cn))) []))`;


(* Do an application *)
(*val do_opapp_i1 : list (maybe v_i1) -> list v_i1 -> maybe (all_env_i1 * exp_i1)*)
val _ = Define `
 (do_opapp_i1 genv vs =  
((case vs of
    [Closure_i1 (cenv, env) n e; v] =>
      SOME ((genv, cenv, bind n v env), e)
  | [Recclosure_i1 (cenv, env) funs n; v] =>
      if ALL_DISTINCT (MAP (\ (f,x,e) .  f) funs) then
        (case find_recfun n funs of
            SOME (n,e) => SOME ((genv, cenv, bind n v (build_rec_env_i1 funs (cenv, env) env)), e)
          | NONE => NONE
        )
      else
        NONE
  | _ => NONE
  )))`;


(*val v_to_list_i1 : v_i1 -> maybe (list v_i1)*)
 val _ = Define `
 (v_to_list_i1 (Conv_i1 (SOME (cn, TypeId (Short tn))) []) =  
 (if (cn = "nil") /\ (tn = "list") then
    SOME []
  else
    NONE))
/\ (v_to_list_i1 (Conv_i1 (SOME (cn,TypeId (Short tn))) [v1;v2]) =  
(if (cn = "::")  /\ (tn = "list") then
    (case v_to_list_i1 v2 of
        SOME vs => SOME (v1::vs)
      | NONE => NONE
    )
  else
    NONE))
/\ (v_to_list_i1 _ = NONE)`;


(*val do_app_i1 : store v_i1 -> op -> list v_i1 -> maybe (store v_i1 * result v_i1 v_i1)*)
val _ = Define `
 (do_app_i1 s op vs =  
((case (op, vs) of
      (Opn op, [Litv_i1 (IntLit n1); Litv_i1 (IntLit n2)]) =>
        if ((op = Divide) \/ (op = Modulo)) /\ (n2 =( 0 : int)) then
          SOME (s, Rerr (Rraise (prim_exn_i1 "Div")))
        else
          SOME (s, Rval (Litv_i1 (IntLit (opn_lookup op n1 n2))))
    | (Opb op, [Litv_i1 (IntLit n1); Litv_i1 (IntLit n2)]) =>
        SOME (s, Rval (Litv_i1 (Bool (opb_lookup op n1 n2))))
    | (Equality, [v1; v2]) =>
        (case do_eq_i1 v1 v2 of
            Eq_type_error => NONE
          | Eq_closure => SOME (s, Rerr (Rraise (prim_exn_i1 "Eq")))
          | Eq_val b => SOME (s, Rval (Litv_i1 (Bool b)))
        )
    | (Opassign, [Loc_i1 lnum; v]) =>
        (case store_assign lnum (Refv v) s of
            SOME st => SOME (st, Rval (Litv_i1 Unit))
          | NONE => NONE
        )
    | (Opref, [v]) =>
        let (s',n) = (store_alloc (Refv v) s) in
          SOME (s', Rval (Loc_i1 n))
    | (Opderef, [Loc_i1 n]) =>
        (case store_lookup n s of
            SOME (Refv v) => SOME (s,Rval v)
          | _ => NONE
        )
    | (Aalloc, [Litv_i1 (IntLit n); Litv_i1 (Word8 w)]) =>
        if n <( 0 : int) then
          SOME (s, Rerr (Rraise (prim_exn_i1 "Subscript")))
        else
          let (s',lnum) =            
(store_alloc (W8array (REPLICATE (Num (ABS ( n))) w)) s)
          in 
            SOME (s', Rval (Loc_i1 lnum))
    | (Asub, [Loc_i1 lnum; Litv_i1 (IntLit i)]) =>
        (case store_lookup lnum s of
            SOME (W8array ws) =>
              if i <( 0 : int) then
                SOME (s, Rerr (Rraise (prim_exn_i1 "Subscript")))
              else
                let n = (Num (ABS ( i))) in
                  if n >= LENGTH ws then
                    SOME (s, Rerr (Rraise (prim_exn_i1 "Subscript")))
                  else 
                    SOME (s, Rval (Litv_i1 (Word8 (EL n ws))))
          | _ => NONE
        )
    | (Alength, [Loc_i1 n]) =>
        (case store_lookup n s of
            SOME (W8array ws) =>
              SOME (s,Rval (Litv_i1(IntLit(int_of_num(LENGTH ws)))))
          | _ => NONE
         )
    | (Aupdate, [Loc_i1 lnum; Litv_i1(IntLit i); Litv_i1(Word8 w)]) =>
        (case store_lookup lnum s of
          SOME (W8array ws) =>
            if i <( 0 : int) then
              SOME (s, Rerr (Rraise (prim_exn_i1 "Subscript")))
            else 
              let n = (Num (ABS ( i))) in
                if n >= LENGTH ws then
                  SOME (s, Rerr (Rraise (prim_exn_i1 "Subscript")))
                else
                  (case store_assign lnum (W8array (LUPDATE w n ws)) s of
                      NONE => NONE
                    | SOME s' => SOME (s', Rval (Litv_i1 Unit))
                  )
        | _ => NONE
        )
    | (VfromList, [v]) =>
          (case v_to_list_i1 v of
              SOME vs =>
                SOME (s, Rval (Vectorv_i1 vs))
            | NONE => NONE
          )
    | (Vsub, [Vectorv_i1 vs; Litv_i1 (IntLit i)]) =>
        if i <( 0 : int) then
          SOME (s, Rerr (Rraise (prim_exn_i1 "Subscript")))
        else
          let n = (Num (ABS ( i))) in
            if n >= LENGTH vs then
              SOME (s, Rerr (Rraise (prim_exn_i1 "Subscript")))
            else 
              SOME (s, Rval (EL n vs))
    | _ => NONE
  )))`;


(*val do_if_i1 : v_i1 -> exp_i1 -> exp_i1 -> maybe exp_i1*)
val _ = Define `
 (do_if_i1 v e1 e2 =  
(if v = Litv_i1 (Bool T) then
    SOME e1
  else if v = Litv_i1 (Bool F) then
    SOME e2
  else
    NONE))`;


(*val pmatch_i1 : envC -> store v_i1 -> pat -> v_i1 -> env varN v_i1 -> match_result (env varN v_i1)*)
 val pmatch_i1_defn = Hol_defn "pmatch_i1" `

(pmatch_i1 envC s (Pvar x) v' env = (Match (bind x v' env)))
/\
(pmatch_i1 envC s (Plit l) (Litv_i1 l') env =  
(if l = l' then
    Match env
  else if lit_same_type l l' then
    No_match
  else
    Match_type_error))
/\
(pmatch_i1 envC s (Pcon (SOME n) ps) (Conv_i1 (SOME (n', t')) vs) env =  
((case lookup_con_id n envC of
      SOME (l, t)=>
        if same_tid t t' /\ (LENGTH ps = l) then
          if same_ctor (id_to_n n, t) (n',t') then
            pmatch_list_i1 envC s ps vs env
          else
            No_match
        else
          Match_type_error
    | _ => Match_type_error
  )))
/\
(pmatch_i1 envC s (Pcon NONE ps) (Conv_i1 NONE vs) env =  
(if LENGTH ps = LENGTH vs then
    pmatch_list_i1 envC s ps vs env
  else
    Match_type_error))
/\
(pmatch_i1 envC s (Pref p) (Loc_i1 lnum) env =  
((case store_lookup lnum s of
      SOME (Refv v) => pmatch_i1 envC s p v env
    | _ => Match_type_error
  )))
/\
(pmatch_i1 envC _ _ _ env = Match_type_error)
/\
(pmatch_list_i1 envC s [] [] env = (Match env))
/\
(pmatch_list_i1 envC s (p::ps) (v::vs) env =  
((case pmatch_i1 envC s p v env of
      No_match => No_match
    | Match_type_error => Match_type_error
    | Match env' => pmatch_list_i1 envC s ps vs env'
  )))
/\
(pmatch_list_i1 envC s _ _ env = Match_type_error)`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn pmatch_i1_defn;

val _ = Hol_reln ` (! ck env l s.
T
==>
evaluate_i1 ck env s (Lit_i1 l) (s, Rval (Litv_i1 l)))

/\ (! ck env e s1 s2 v.
(evaluate_i1 ck s1 env e (s2, Rval v))
==>
evaluate_i1 ck s1 env (Raise_i1 e) (s2, Rerr (Rraise v)))

/\ (! ck env e s1 s2 err.
(evaluate_i1 ck s1 env e (s2, Rerr err))
==>
evaluate_i1 ck s1 env (Raise_i1 e) (s2, Rerr err))

/\ (! ck s1 s2 env e v pes.
(evaluate_i1 ck s1 env e (s2, Rval v))
==>
evaluate_i1 ck s1 env (Handle_i1 e pes) (s2, Rval v))

/\ (! ck s1 s2 env e pes v bv.
(evaluate_i1 ck env s1 e (s2, Rerr (Rraise v)) /\
evaluate_match_i1 ck env s2 v pes v bv)
==>
evaluate_i1 ck env s1 (Handle_i1 e pes) bv)

/\ (! ck s1 s2 env e pes err.
(evaluate_i1 ck env s1 e (s2, Rerr err) /\
((err = Rtimeout_error) \/ (err = Rtype_error)))
==>
evaluate_i1 ck env s1 (Handle_i1 e pes) (s2, Rerr err))

/\ (! ck env cn es vs s s' v.
(do_con_check (all_env_i1_to_cenv env) cn (LENGTH es) /\
(build_conv_i1 (all_env_i1_to_cenv env) cn vs = SOME v) /\
evaluate_list_i1 ck env s es (s', Rval vs))
==>
evaluate_i1 ck env s (Con_i1 cn es) (s', Rval v))

/\ (! ck env cn es s.
(~ (do_con_check (all_env_i1_to_cenv env) cn (LENGTH es)))
==>
evaluate_i1 ck env s (Con_i1 cn es) (s, Rerr Rtype_error))

/\ (! ck env cn es err s s'.
(do_con_check (all_env_i1_to_cenv env) cn (LENGTH es) /\
evaluate_list_i1 ck env s es (s', Rerr err))
==>
evaluate_i1 ck env s (Con_i1 cn es) (s', Rerr err))

/\ (! ck env n v s.
(lookup n (all_env_i1_to_env env) = SOME v)
==>
evaluate_i1 ck env s (Var_local_i1 n) (s, Rval v))

/\ (! ck env n s.
(lookup n (all_env_i1_to_env env) = NONE)
==>
evaluate_i1 ck env s (Var_local_i1 n) (s, Rerr Rtype_error))

/\ (! ck env n v s.
((LENGTH (all_env_i1_to_genv env) > n) /\
(EL n (all_env_i1_to_genv env) = SOME v))
==>
evaluate_i1 ck env s (Var_global_i1 n) (s, Rval v))

/\ (! ck env n s.
((LENGTH (all_env_i1_to_genv env) > n) /\
(EL n (all_env_i1_to_genv env) = NONE))
==>
evaluate_i1 ck env s (Var_global_i1 n) (s, Rerr Rtype_error))

/\ (! ck env n s.
(~ (LENGTH (all_env_i1_to_genv env) > n))
==>
evaluate_i1 ck env s (Var_global_i1 n) (s, Rerr Rtype_error))

/\ (! ck env n e s.
T
==>
evaluate_i1 ck env s (Fun_i1 n e) (s, Rval (Closure_i1 (all_env_i1_to_cenv env, all_env_i1_to_env env) n e)))

/\ (! ck env es vs env' e bv s1 s2 count.
(evaluate_list_i1 ck env s1 es ((count,s2), Rval vs) /\
(do_opapp_i1 (all_env_i1_to_genv env) vs = SOME (env', e)) /\
(ck ==> ~ (count =( 0))) /\
evaluate_i1 ck env' ((if ck then count -  1 else count),s2) e bv)
==>
evaluate_i1 ck env s1 (App_i1 Opapp es) bv)

/\ (! ck env es vs env' e s1 s2 count.
(evaluate_list_i1 ck env s1 es ((count,s2), Rval vs) /\
(do_opapp_i1 (all_env_i1_to_genv env) vs = SOME (env', e)) /\
(count = 0) /\
ck)
==>
evaluate_i1 ck env s1 (App_i1 Opapp es) (( 0,s2), Rerr Rtimeout_error))

/\ (! ck env es vs s1 s2.
(evaluate_list_i1 ck env s1 es (s2, Rval vs) /\
(do_opapp_i1 (all_env_i1_to_genv env) vs = NONE))
==>
evaluate_i1 ck env s1 (App_i1 Opapp es) (s2, Rerr Rtype_error))

/\ (! ck env op es vs res s1 s2 s3 count.
(evaluate_list_i1 ck env s1 es ((count,s2), Rval vs) /\
(do_app_i1 s2 op vs = SOME (s3, res)) /\
(op <> Opapp))
==>
evaluate_i1 ck env s1 (App_i1 op es) ((count,s3), res))

/\ (! ck env op es vs s1 s2 count.
(evaluate_list_i1 ck env s1 es ((count,s2), Rval vs) /\
(do_app_i1 s2 op vs = NONE) /\
(op <> Opapp))
==>
evaluate_i1 ck env s1 (App_i1 op es) ((count,s2), Rerr Rtype_error))

/\ (! ck env op es err s1 s2.
(evaluate_list_i1 ck env s1 es (s2, Rerr err))
==>
evaluate_i1 ck env s1 (App_i1 op es) (s2, Rerr err))

/\ (! ck env e1 e2 e3 v e' bv s1 s2.
(evaluate_i1 ck env s1 e1 (s2, Rval v) /\
(do_if_i1 v e2 e3 = SOME e') /\
evaluate_i1 ck env s2 e' bv)
==>
evaluate_i1 ck env s1 (If_i1 e1 e2 e3) bv)

/\ (! ck env e1 e2 e3 v s1 s2.
(evaluate_i1 ck env s1 e1 (s2, Rval v) /\
(do_if_i1 v e2 e3 = NONE))
==>
evaluate_i1 ck env s1 (If_i1 e1 e2 e3) (s2, Rerr Rtype_error))

/\ (! ck env e1 e2 e3 err s s'.
(evaluate_i1 ck env s e1 (s', Rerr err))
==>
evaluate_i1 ck env s (If_i1 e1 e2 e3) (s', Rerr err))

/\ (! ck env e pes v bv s1 s2.
(evaluate_i1 ck env s1 e (s2, Rval v) /\
evaluate_match_i1 ck env s2 v pes (Conv_i1 (SOME ("Bind", TypeExn (Short "Bind"))) []) bv)
==>
evaluate_i1 ck env s1 (Mat_i1 e pes) bv)

/\ (! ck env e pes err s s'.
(evaluate_i1 ck env s e (s', Rerr err))
==>
evaluate_i1 ck env s (Mat_i1 e pes) (s', Rerr err))

/\ (! ck genv cenv env n e1 e2 v bv s1 s2.
(evaluate_i1 ck (genv,cenv,env) s1 e1 (s2, Rval v) /\
evaluate_i1 ck (genv,cenv,opt_bind n v env) s2 e2 bv)
==>
evaluate_i1 ck (genv,cenv,env) s1 (Let_i1 n e1 e2) bv)

/\ (! ck env n e1 e2 err s s'.
(evaluate_i1 ck env s e1 (s', Rerr err))
==>
evaluate_i1 ck env s (Let_i1 n e1 e2) (s', Rerr err))

/\ (! ck genv cenv env funs e bv s.
(ALL_DISTINCT (MAP (\ (x,y,z) .  x) funs) /\
evaluate_i1 ck (genv,cenv,build_rec_env_i1 funs (cenv,env) env) s e bv)
==>
evaluate_i1 ck (genv,cenv,env) s (Letrec_i1 funs e) bv)

/\ (! ck env funs e s.
(~ (ALL_DISTINCT (MAP (\ (x,y,z) .  x) funs)))
==>
evaluate_i1 ck env s (Letrec_i1 funs e) (s, Rerr Rtype_error))

/\ (! ck env s.
T
==>
evaluate_list_i1 ck env s [] (s, Rval []))

/\ (! ck env e es v vs s1 s2 s3.
(evaluate_i1 ck env s1 e (s2, Rval v) /\
evaluate_list_i1 ck env s2 es (s3, Rval vs))
==>
evaluate_list_i1 ck env s1 (e::es) (s3, Rval (v::vs)))

/\ (! ck env e es err s s'.
(evaluate_i1 ck env s e (s', Rerr err))
==>
evaluate_list_i1 ck env s (e::es) (s', Rerr err))

/\ (! ck env e es v err s1 s2 s3.
(evaluate_i1 ck env s1 e (s2, Rval v) /\
evaluate_list_i1 ck env s2 es (s3, Rerr err))
==>
evaluate_list_i1 ck env s1 (e::es) (s3, Rerr err))

/\ (! ck env v err_v s.
T
==>
evaluate_match_i1 ck env s v [] err_v (s, Rerr (Rraise err_v)))

/\ (! ck genv cenv env env' v p pes e bv err_v s count.
(ALL_DISTINCT (pat_bindings p []) /\
(pmatch_i1 cenv s p v env = Match env') /\
evaluate_i1 ck (genv,cenv,env') (count,s) e bv)
==>
evaluate_match_i1 ck (genv,cenv,env) (count,s) v ((p,e)::pes) err_v bv)

/\ (! ck genv cenv env v p e pes bv s count err_v.
(ALL_DISTINCT (pat_bindings p []) /\
(pmatch_i1 cenv s p v env = No_match) /\
evaluate_match_i1 ck (genv,cenv,env) (count,s) v pes err_v bv)
==>
evaluate_match_i1 ck (genv,cenv,env) (count,s) v ((p,e)::pes) err_v bv)

/\ (! ck genv cenv env v p e pes s count err_v.
(pmatch_i1 cenv s p v env = Match_type_error)
==>
evaluate_match_i1 ck (genv,cenv,env) (count,s) v ((p,e)::pes) err_v ((count,s), Rerr Rtype_error))

/\ (! ck env v p e pes s err_v.
(~ (ALL_DISTINCT (pat_bindings p [])))
==>
evaluate_match_i1 ck env s v ((p,e)::pes) err_v (s, Rerr Rtype_error))`;

val _ = Hol_reln ` (! ck genv cenv n e vs s1 s2 tdecs.
(evaluate_i1 ck (genv,cenv,emp) s1 e (s2, Rval (Conv_i1 NONE vs)) /\
(LENGTH vs = n))
==>
evaluate_dec_i1 ck genv cenv (s1,tdecs) (Dlet_i1 n e) ((s2,tdecs), Rval (emp, vs)))

/\ (! ck genv cenv n e vs s1 s2 tdecs.
(evaluate_i1 ck (genv,cenv,emp) s1 e (s2, Rval (Conv_i1 NONE vs)) /\ ~ ((LENGTH vs) = n))
==>
evaluate_dec_i1 ck genv cenv (s1,tdecs) (Dlet_i1 n e) ((s2,tdecs), Rerr Rtype_error))

/\ (! ck genv cenv n e v s1 s2 tdecs.
(evaluate_i1 ck (genv,cenv,emp) s1 e (s2, Rval v) /\
~ (? vs. v = Conv_i1 NONE vs))
==>
evaluate_dec_i1 ck genv cenv (s1,tdecs) (Dlet_i1 n e) ((s2,tdecs), Rerr Rtype_error))

/\ (! ck genv cenv n e err s s' tdecs.
(evaluate_i1 ck (genv,cenv,emp) s e (s', Rerr err))
==>
evaluate_dec_i1 ck genv cenv (s,tdecs) (Dlet_i1 n e) ((s',tdecs), Rerr err))

/\ (! ck genv cenv funs s.
T
==>
evaluate_dec_i1 ck genv cenv s (Dletrec_i1 funs) (s, Rval (emp, MAP (\ (f,x,e) .  Closure_i1 (cenv,[]) x e) funs)))

/\ (! ck mn genv cenv tds s tdecs new_tdecs.
(check_dup_ctors tds /\
(new_tdecs = type_defs_to_new_tdecs mn tds) /\
DISJOINT new_tdecs tdecs /\
ALL_DISTINCT (MAP (\ (tvs,tn,ctors) .  tn) tds))
==>
evaluate_dec_i1 ck genv cenv (s,tdecs) (Dtype_i1 mn tds) ((s,(new_tdecs UNION tdecs)), Rval (build_tdefs mn tds, [])))

/\ (! ck mn genv cenv tds s tdecs.
(~ (check_dup_ctors tds) \/
(~ (DISJOINT (type_defs_to_new_tdecs mn tds) tdecs) \/
~ (ALL_DISTINCT (MAP (\ (tvs,tn,ctors) .  tn) tds))))
==>
evaluate_dec_i1 ck genv cenv (s,tdecs) (Dtype_i1 mn tds) ((s,tdecs), Rerr Rtype_error))

/\ (! ck mn genv cenv cn ts s tdecs.
(~ (TypeExn (mk_id mn cn) IN tdecs))
==>
evaluate_dec_i1 ck genv cenv (s,tdecs) (Dexn_i1 mn cn ts) ((s, ({TypeExn (mk_id mn cn)} UNION tdecs)), Rval (bind cn (LENGTH ts, TypeExn (mk_id mn cn)) emp, [])))

/\ (! ck mn genv cenv cn ts s tdecs.
(TypeExn (mk_id mn cn) IN tdecs)
==>
evaluate_dec_i1 ck genv cenv (s,tdecs) (Dexn_i1 mn cn ts) ((s,tdecs), Rerr Rtype_error))`;

val _ = Hol_reln ` (! ck genv cenv s.
T
==>
evaluate_decs_i1 ck genv cenv s [] (s, emp, [], NONE))

/\ (! ck s1 s2 genv cenv d ds e.
(evaluate_dec_i1 ck genv cenv s1 d (s2, Rerr e))
==>
evaluate_decs_i1 ck genv cenv s1 (d::ds) (s2, emp, [], SOME e))

/\ (! ck s1 s2 s3 genv cenv d ds new_tds' new_tds new_env new_env' r.
(evaluate_dec_i1 ck genv cenv s1 d (s2, Rval (new_tds,new_env)) /\
evaluate_decs_i1 ck (genv ++ MAP SOME new_env) (merge_envC (emp,new_tds) cenv) s2 ds (s3, new_tds', new_env', r))
==>
evaluate_decs_i1 ck genv cenv s1 (d::ds) (s3, merge new_tds' new_tds, (new_env ++ new_env'), r))`;

(*val mod_cenv : maybe modN -> flat_envC -> envC*)
val _ = Define `
 (mod_cenv mn cenv =  
((case mn of
      NONE => ([],cenv)
    | SOME mn => ([(mn,cenv)],[])
  )))`;


(*val update_mod_state : maybe modN -> set modN -> set modN*)
val _ = Define `
 (update_mod_state mn mods =  
((case mn of
      NONE => mods
    | SOME mn => {mn} UNION mods
  )))`;


 val _ = Define `

(dec_to_dummy_env (Dlet_i1 n e) = n)
/\
(dec_to_dummy_env (Dletrec_i1 funs) = (LENGTH funs))
/\
(dec_to_dummy_env _ =( 0))`;
 

 val _ = Define `

(decs_to_dummy_env [] =( 0))
/\
(decs_to_dummy_env (d::ds) = (decs_to_dummy_env ds + dec_to_dummy_env d))`;


(*val decs_to_types_i1 : list dec_i1 -> list typeN*)
val _ = Define `
 (decs_to_types_i1 ds =   
(FLAT (MAP (\ d .  
        (case d of 
            Dtype_i1 mn tds => MAP (\ (tvs,tn,ctors) .  tn) tds
          | _ => [] ))
     ds)))`;


(*val no_dup_types_i1 : list dec_i1 -> bool*)
val _ = Define `
 (no_dup_types_i1 ds =  
(ALL_DISTINCT (decs_to_types_i1 ds)))`;


(*val prompt_mods_ok : maybe modN -> list dec_i1 -> bool*)
val _ = Define `
 (prompt_mods_ok mn ds =  
(((case mn of
       NONE => LENGTH ds < 2
     | SOME mn => T
   ))
  /\
  (EVERY (\ d . 
      (case d of
          Dtype_i1 mn' _ => mn' = mn
        | Dexn_i1 mn' _ _ => mn' = mn
        | _ => T
      ))
    ds)))`;


val _ = Hol_reln ` (! ck genv cenv s1 tdecs1 mods ds s2 tdecs2 cenv' env mn.
((! name. (mn = SOME name) ==> ~ (name IN mods)) /\
no_dup_types_i1 ds /\
prompt_mods_ok mn ds /\
evaluate_decs_i1 ck genv cenv (s1,tdecs1) ds ((s2,tdecs2),cenv',env,NONE))
==>
evaluate_prompt_i1 ck genv cenv (s1,tdecs1,mods) (Prompt_i1 mn ds) ((s2,tdecs2,update_mod_state mn mods), mod_cenv mn cenv', MAP SOME env, NONE))

/\ (! ck genv cenv s1 tdecs1 mods mn ds s2 tdecs2 cenv' env err.
((! name. (mn = SOME name) ==> ~ (name IN mods)) /\
no_dup_types_i1 ds /\
prompt_mods_ok mn ds /\
evaluate_decs_i1 ck genv cenv (s1,tdecs1) ds ((s2,tdecs2),cenv',env,SOME err))
==>
evaluate_prompt_i1 ck genv cenv (s1,tdecs1,mods) (Prompt_i1 mn ds) 
                                                  ((s2,tdecs2,update_mod_state mn mods),
                                                   mod_cenv mn cenv',                                                   
 (MAP SOME env ++ GENLIST (\n .  
  (case (n ) of ( _ ) => NONE )) (decs_to_dummy_env ds - LENGTH env)),
                                                   SOME err))

/\ (! ck genv cenv s1 tdecs1 mods mn ds.
(~ (no_dup_types_i1 ds) \/ ~ (prompt_mods_ok mn ds))
==>
evaluate_prompt_i1 ck genv cenv (s1,tdecs1,mods) (Prompt_i1 mn ds) ((s1,tdecs1,mods), ([],[]), [], SOME Rtype_error))

/\ (! ck genv cenv s1 tdecs1 mods mn ds.
(? name. (mn = SOME name) /\ (name IN mods))
==>
evaluate_prompt_i1 ck genv cenv (s1,tdecs1,mods) (Prompt_i1 mn ds) ((s1,tdecs1,mods), ([],[]), [], SOME Rtype_error))`;

val _ = Hol_reln ` (! ck genv cenv s.
T
==>
evaluate_prog_i1 ck genv cenv s [] (s, ([],[]), [], NONE))

/\ (! ck genv cenv s1 prompt prompts s2 cenv2 env2 s3 cenv3 env3 r.
(evaluate_prompt_i1 ck genv cenv s1 prompt (s2, cenv2, env2, NONE) /\
evaluate_prog_i1 ck (genv++env2) (merge_envC cenv2 cenv) s2 prompts (s3, cenv3, env3, r))
==>
evaluate_prog_i1 ck genv cenv s1 (prompt::prompts) (s3, merge_envC cenv3 cenv2, (env2++env3), r))

/\ (! ck genv cenv s1 prompt prompts s2 cenv2 env2 err.
(evaluate_prompt_i1 ck genv cenv s1 prompt (s2, cenv2, env2, SOME err))
==>
evaluate_prog_i1 ck genv cenv s1 (prompt::prompts) (s2, cenv2, env2, SOME err))`;

(*val prog_i1_to_mods : list prompt_i1 -> list modN*)
val _ = Define `
 (prog_i1_to_mods prompts =  
(FLAT (MAP (\ prompt .  
        (case prompt of 
            Prompt_i1 (SOME mn) ds => [mn]
          | _ => [] ))
     prompts)))`;


(*val no_dup_mods_i1 : list prompt_i1 -> count_store v_i1 * set tid_or_exn * set modN -> bool*)
val _ = Define `
 (no_dup_mods_i1 prompts (_,_,mods) =  
(ALL_DISTINCT (prog_i1_to_mods prompts) /\
  DISJOINT (LIST_TO_SET (prog_i1_to_mods prompts)) mods))`;


(*val prog_i1_to_top_types : list prompt_i1 -> list typeN*)
val _ = Define `
 (prog_i1_to_top_types prompts =  
(FLAT (MAP (\ prompt .  
        (case prompt of 
            Prompt_i1 NONE ds => decs_to_types_i1 ds
          | _ => [] ))
     prompts)))`;
 

(*val no_dup_top_types_i1 : list prompt_i1 -> count_store v_i1 * set tid_or_exn * set modN -> bool*)
val _ = Define `
 (no_dup_top_types_i1 prompts (_, tids, _) =  
(ALL_DISTINCT (prog_i1_to_top_types prompts) /\
  DISJOINT (LIST_TO_SET (MAP (\ tn .  TypeId (Short tn)) (prog_i1_to_top_types prompts))) tids))`;


(*val evaluate_whole_prog_i1 : bool -> list (maybe v_i1) -> envC -> count_store v_i1 * set tid_or_exn * set modN -> list prompt_i1 -> (count_store v_i1 * set tid_or_exn * set modN) * envC * list (maybe v_i1) * maybe (error_result v_i1) -> bool*)
val _ = Define `
 (evaluate_whole_prog_i1 ck genv cenv s1 prompts (s2, cenv2, env2, res) =  
(if no_dup_mods_i1 prompts s1 /\ no_dup_top_types_i1 prompts s1 /\
     EVERY (\ p .  (case p of Prompt_i1 mn ds => prompt_mods_ok mn ds )) prompts then
    evaluate_prog_i1 ck genv cenv s1 prompts (s2, cenv2, env2, res)
  else
    res = SOME Rtype_error))`;
 
val _ = export_theory()

