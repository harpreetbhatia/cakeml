open preamble
     semanticPrimitivesTheory
     dec_to_exhTheory
     exhSemTheory exhPropsTheory

val _ = new_theory "dec_to_exhProof";

val find_recfun_compile_funs = prove(
  ``∀ls f exh. find_recfun f (compile_funs exh ls) =
               OPTION_MAP (λ(x,y). (x,compile_exp exh y)) (find_recfun f ls)``,
  Induct >> simp[compile_funs_map] >- (
    simp[semanticPrimitivesTheory.find_recfun_def] ) >>
  simp[Once semanticPrimitivesTheory.find_recfun_def] >>
  simp[Once semanticPrimitivesTheory.find_recfun_def,SimpRHS] >>
  rpt gen_tac >>
  every_case_tac >>
  simp[] >> fs[compile_funs_map]);

val exhaustive_match_submap = prove(
  ``exhaustive_match exh pes ∧ exh ⊑ exh2 ⇒ exhaustive_match exh2 pes``,
  rw[exhaustive_match_def] >>
  every_case_tac >> fs[] >>
  imp_res_tac FLOOKUP_SUBMAP >> fs[] >> rw[])

(* value relation *)

val get_tag_def = Define`
  get_tag NONE = tuple_tag ∧
  get_tag (SOME p) = FST p`
val _ = export_rewrites["get_tag_def"]

val (v_rel_rules, v_rel_ind, v_rel_cases) = Hol_reln `
  (!exh l.
    v_rel exh (Litv l) (Litv l)) ∧
  (!exh t vs vs'.
    vs_rel exh vs vs'
    ⇒
    v_rel exh (Conv t vs) (Conv (get_tag t) vs')) ∧
  (!exh env x e env' exh'.
    exh' SUBMAP exh ∧
    env_rel exh env env'
    ⇒
    v_rel exh (Closure env x e) (Closure env' x (compile_exp exh' e))) ∧
  (!exh env x funs exh'.
    exh' SUBMAP exh ∧
    env_rel exh env env'
    ⇒
    v_rel exh (Recclosure env funs x) (Recclosure env' (compile_funs exh' funs) x)) ∧
  (!exh l.
    v_rel exh (Loc l) (Loc l)) ∧
  (!exh vs vs'.
    vs_rel exh vs vs'
    ⇒
    v_rel exh (Vectorv vs) (Vectorv vs')) ∧
  (!exh.
    vs_rel exh [] []) ∧
  (!exh v v' vs vs'.
    v_rel exh v v' ∧
    vs_rel exh vs vs'
    ⇒
    vs_rel exh (v::vs) (v'::vs')) ∧
  (!exh.
    env_rel exh [] []) ∧
  (!exh x v v' env env'.
    v_rel exh v v' ∧
    env_rel exh env env'
    ⇒
    env_rel exh ((x,v)::env) ((x,v')::env'))`;

val v_rel_eqn = Q.prove (
  `(!exh l v.
    v_rel exh (Litv l) v ⇔
     v = Litv l) ∧
   (!exh t vs v.
    v_rel exh (Conv t vs) v ⇔
     ?vs'.
      vs_rel exh vs vs' ∧
      v = Conv (get_tag t) vs') ∧
   (!exh l.
    v_rel exh (Loc l) v ⇔
     v = Loc l) ∧
   (!exh vs v.
    v_rel exh (Vectorv vs) v ⇔
     ?vs'.
      vs_rel exh vs vs' ∧
      v = Vectorv vs') ∧
   (!exh vs. vs_rel exh [] vs ⇔ vs = []) ∧
   (!exh v vs vs'.
    vs_rel exh (v::vs) vs' ⇔
    ?v' vs''.
      vs' = v'::vs'' ∧
      v_rel exh v v' ∧
      vs_rel exh vs vs'') ∧
   (!exh env. env_rel exh [] env ⇔ env = []) ∧
   (!exh x v env env'.
    env_rel exh ((x,v)::env) env' ⇔
    ?v' env''.
      env' = (x,v') :: env'' ∧
      v_rel exh v v' ∧
      env_rel exh env env'')`,
   rw [] >>
   rw [Once v_rel_cases] >>
   metis_tac []);

val vs_rel_LIST_REL = prove(
  ``∀vs vs' exh. vs_rel exh vs vs' = LIST_REL (v_rel exh) vs vs'``,
  Induct >> simp[v_rel_eqn])

val env_rel_LIST_REL = Q.prove(
  `!exh env env'. env_rel exh env env' = LIST_REL (λ(x,y) (x',y'). x = x' ∧ v_rel exh y y') env env'`,
  Induct_on`env`>>simp[v_rel_eqn]>>Cases>>simp[v_rel_eqn] >>
  rw [EXISTS_PROD]);

val env_rel_MAP = store_thm("env_rel_MAP",
  ``∀exh env1 env2. env_rel exh env1 env2 ⇔ MAP FST env1 = MAP FST env2 ∧
      LIST_REL (v_rel exh) (MAP SND env1) (MAP SND env2)``,
  Induct_on`env1`>>simp[Once v_rel_cases] >>
  Cases >> Cases_on`env2` >> rw[] >>
  Cases_on`h`>>rw[] >> metis_tac[])

val _ = augment_srw_ss[rewrites[vs_rel_LIST_REL,find_recfun_compile_funs]]

val v_rel_lit_loc = store_thm("v_rel_lit_loc[simp]",
  ``(v_rel exh (Litv l) lh ⇔ lh = Litv l) ∧
    (v_rel exh l2 (Litv l) ⇔ l2 = Litv l) ∧
    (v_rel exh (Loc n) lh ⇔ lh = Loc n) ∧
    (v_rel exh l2 (Loc n) ⇔ l2 = Loc n) ∧
    (v_rel exh (Conv t []) lh ⇔ lh = Conv (get_tag t) []) ∧
    (v_rel exh (Boolv b) lh ⇔ lh = Boolv b)``,
  rw[] >> rw[Once v_rel_cases, conSemTheory.Boolv_def, exhSemTheory.Boolv_def])

val state_rel_def = Define`
  state_rel exh s1 s2 ⇔
    s1.clock = s2.clock ∧
    LIST_REL (sv_rel (v_rel exh)) s1.refs s2.refs ∧
    s1.ffi = s2.ffi ∧
    LIST_REL (OPTION_REL (v_rel exh)) s1.globals s2.globals`;

val state_rel_dec_clock = Q.store_thm("state_rel_dec_clock",
  `state_rel exh s1 s2 ⇒ state_rel exh (dec_clock s1) (dec_clock s2)`,
  EVAL_TAC >> rw[])

val state_rel_with_clock = Q.store_thm("state_rel_with_clock",
  `∀k. state_rel exh s1 s2 ⇒ state_rel exh (s1 with clock := k) (s2 with clock := k)`,
  EVAL_TAC >> rw[])

val (result_rel_rules, result_rel_ind, result_rel_cases) = Hol_reln `
  (∀exh v v' s s'.
    f exh v v' ∧
    state_rel exh s s'
    ⇒
    result_rel f exh (s,Rval v) (s',Rval v')) ∧
  (∀exh v v' s s'.
    v_rel exh v v' ∧
    state_rel exh s s'
    ⇒
    result_rel f exh (s,Rerr (Rraise v)) (s',Rerr (Rraise v'))) ∧
  (!exh s s' a.
    state_rel exh s s'
    ⇒
    result_rel f exh (s,Rerr (Rabort a)) (s',Rerr (Rabort a)))`;

val result_rel_simp = save_thm("result_rel_simp[simp]",
  [``result_rel R x (s,Rval a) res``,
   ``result_rel R x res (s,Rval a)``,
   ``result_rel R x (s,Rerr (Rraise z)) res``,
   ``result_rel R x res (s,Rerr (Rraise z))``,
   ``result_rel R x (s,Rerr (Rabort a)) res``,
   ``result_rel R x res (s,Rerr (Rabort a))``]
  |> map (SIMP_CONV(srw_ss())[result_rel_cases])
  |> LIST_CONJ)

val result_rel_list_result = Q.store_thm("result_rel_list_result",
  `result_rel v_rel x (a,r) (b,s) ⇔
   result_rel vs_rel x (a,list_result r) (b,list_result s)`,
  rw[result_rel_cases,EQ_IMP_THM] >> fs[])

val match_result_rel_def = Define
  `(match_result_rel exh (Match env) (Match env_exh) ⇔
     env_rel exh env env_exh) ∧
   (match_result_rel exh No_match No_match = T) ∧
   (match_result_rel exh Match_type_error Match_type_error = T) ∧
   (match_result_rel exh _ _ = F)`;

val match_result_error = Q.prove (
  `(!exh r. match_result_rel exh r Match_type_error ⇔ r = Match_type_error) ∧
   (!exh r. match_result_rel exh Match_type_error r ⇔ r = Match_type_error)`,
  rw [] >>
  cases_on `r` >>
  rw [match_result_rel_def]);

val match_result_nomatch = Q.prove (
  `(!exh r. match_result_rel exh r No_match ⇔ r = No_match) ∧
   (!exh r. match_result_rel exh No_match r ⇔ r = No_match)`,
  rw [] >>
  cases_on `r` >>
  rw [match_result_rel_def]);

(* semantic functions preserve relation *)

val do_eq = Q.prove (
  `(!v1 v2 tagenv r v1_exh v2_exh (exh:exh_ctors_env).
    do_eq v1 v2 = r ∧ r ≠ Eq_type_error ∧
    v_rel exh v1 v1_exh ∧
    v_rel exh v2 v2_exh
    ⇒
    do_eq v1_exh v2_exh = r) ∧
   (!vs1 vs2 tagenv r vs1_exh vs2_exh (exh:exh_ctors_env).
    do_eq_list vs1 vs2 = r ∧ r ≠ Eq_type_error ∧
    vs_rel exh vs1 vs1_exh ∧
    vs_rel exh vs2 vs2_exh
    ⇒
    do_eq_list vs1_exh vs2_exh = r)`,
  ho_match_mp_tac conSemTheory.do_eq_ind >>
  reverse(rw[exhSemTheory.do_eq_def,conSemTheory.do_eq_def,v_rel_eqn]) >>
  rw[v_rel_eqn, exhSemTheory.do_eq_def] >>
  fs[exhSemTheory.do_eq_def]
  >- (every_case_tac >>
      rw [] >>
      fs [] >>
      metis_tac [eq_result_distinct, eq_result_11]) >>
  fs [Once v_rel_cases] >>
  rw [exhSemTheory.do_eq_def] >>
  fs [] >>
  TRY(metis_tac [LIST_REL_LENGTH])
  >> (
    Cases_on`t1`>>fs[] >>
    Cases_on`t2`>>fs[] >>
    rfs[] >> rw[] >> fs[])) ;

val pmatch = Q.prove (
  `(!(exh:exh_ctors_env) s p v env r env_exh s_exh v_exh.
    r ≠ Match_type_error ∧
    pmatch exh s p v env = r ∧
    LIST_REL (sv_rel (v_rel exh)) s s_exh ∧
    v_rel exh v v_exh ∧
    env_rel exh env env_exh
    ⇒
    ?r_exh.
      pmatch s_exh (compile_pat p) v_exh env_exh = r_exh ∧
      match_result_rel exh r r_exh) ∧
   (!(exh:exh_ctors_env) s ps vs env r env_exh s_exh vs_exh.
    r ≠ Match_type_error ∧
    pmatch_list exh s ps vs env = r ∧
    LIST_REL (sv_rel (v_rel exh)) s s_exh ∧
    vs_rel exh vs vs_exh ∧
    env_rel exh env env_exh
    ⇒
    ?r_exh.
      pmatch_list s_exh (MAP compile_pat ps) vs_exh env_exh = r_exh ∧
      match_result_rel exh r r_exh)`,
  ho_match_mp_tac conSemTheory.pmatch_ind >>
  rw [conSemTheory.pmatch_def, exhSemTheory.pmatch_def, compile_pat_def, match_result_rel_def] >>
  fs [match_result_rel_def, v_rel_eqn] >>
  rw [exhSemTheory.pmatch_def, match_result_rel_def, match_result_error] >>
  imp_res_tac LIST_REL_LENGTH >>
  fs []
  >- metis_tac []
  >- (every_case_tac >>
      fs [LET_THM] >>
      pop_assum mp_tac >> simp[] >>
      rw[] >> rfs[] >> fs[] >>
      metis_tac [])
  >- (every_case_tac >>
      fs [LET_THM] >>
      pop_assum mp_tac >> simp[] >>
      BasicProvers.CASE_TAC >> simp[]>>
      rw[match_result_rel_def])
  >- (every_case_tac >>
      fs[LET_THM] >>
      pop_assum mp_tac >> simp[] >>
      BasicProvers.CASE_TAC >> simp[]>>
      rw[match_result_rel_def])
  >- metis_tac []
  >- (every_case_tac >>
      fs [match_result_error, store_lookup_def, LIST_REL_EL_EQN] >>
      rfs[] >> metis_tac [evalPropsTheory.sv_rel_def])
  >- (every_case_tac >>
      rw [match_result_rel_def] >>
      res_tac >>
      fs [match_result_nomatch] >>
      cases_on `pmatch s_exh (compile_pat p) y env_exh` >>
      fs [match_result_rel_def] >>
      metis_tac []));

val pat_bindings = prove(
  ``(∀p ls. pat_bindings (compile_pat p) ls = pat_bindings p ls) ∧
    (∀ps ls. pats_bindings (MAP compile_pat ps) ls = pats_bindings ps ls)``,
  ho_match_mp_tac(TypeBase.induction_of(``:conLang$pat``)) >>
  simp[conSemTheory.pat_bindings_def,exhSemTheory.pat_bindings_def,compile_pat_def] >>
  rw[] >> cases_on`o'` >>
  TRY(cases_on`x`)>>
  rw[compile_pat_def,exhSemTheory.pat_bindings_def,ETA_AX])

val v_to_list = Q.prove (
  `!v1 v2 vs1.
    v_rel genv v1 v2 ∧
    v_to_list v1 = SOME vs1
    ⇒
    ?vs2.
      v_to_list v2 = SOME vs2 ∧
      vs_rel genv vs1 vs2`,
  ho_match_mp_tac conSemTheory.v_to_list_ind >>
  rw [conSemTheory.v_to_list_def] >>
  every_case_tac >>
  fs [v_rel_eqn, exhSemTheory.v_to_list_def] >>
  rw [] >>
  every_case_tac >>
  fs [v_rel_eqn, exhSemTheory.v_to_list_def] >>
  rw [] >>
  metis_tac [NOT_SOME_NONE, SOME_11]);

val char_list_to_v = prove(
  ``∀ls. v_rel exh (char_list_to_v ls) (char_list_to_v ls)``,
  Induct >> simp[conSemTheory.char_list_to_v_def,exhSemTheory.char_list_to_v_def] >>
  simp[v_rel_eqn])

val v_to_char_list = Q.prove (
  `!v1 v2 vs1.
    v_rel genv v1 v2 ∧
    v_to_char_list v1 = SOME vs1
    ⇒
    v_to_char_list v2 = SOME vs1`,
  ho_match_mp_tac conSemTheory.v_to_char_list_ind >>
  rw [conSemTheory.v_to_char_list_def] >>
  every_case_tac >>
  fs [v_rel_eqn, exhSemTheory.v_to_char_list_def]);

val tac =
  rw [exhSemTheory.do_app_def, result_rel_cases, conSemTheory.prim_exn_def, conSemTheory.exn_tag_def,
      exhSemTheory.prim_exn_def, v_rel_eqn, conSemTheory.Boolv_def, exhSemTheory.Boolv_def] >>
  fs [] >>
  fs [store_assign_def,store_lookup_def, store_alloc_def,
      LET_THM] >>
  rw [] >>
  imp_res_tac LIST_REL_LENGTH >>
  fs [conSemTheory.prim_exn_def, v_rel_eqn, conSemTheory.exn_tag_def] >>
  every_case_tac >>
  fs [LIST_REL_EL_EQN, EL_LUPDATE,state_rel_def] >>
  rw [EL_LUPDATE, evalPropsTheory.sv_rel_def] >>
  res_tac >>
  pop_assum mp_tac >>
  ASM_REWRITE_TAC [evalPropsTheory.sv_rel_def] >>
  fs [v_rel_eqn, store_v_same_type_def] >>
  every_case_tac >>
  fs [] >> rfs[];

val do_app_lem = Q.prove (
  `!(exh:exh_ctors_env) s1 op vs r' ffi' res s1_exh vs_exh.
    conSem$do_app (s1.refs,s1.ffi) op vs = SOME ((r',ffi'), res) ∧
    state_rel exh s1 s1_exh ∧
    vs_rel exh vs vs_exh
    ⇒
     ∃s2_exh res_exh.
       result_rel v_rel exh (s1 with <| refs := r'; ffi := ffi'|>,res) (s2_exh,res_exh) ∧
       do_app s1_exh op vs_exh = SOME (s2_exh, res_exh)`,
  rw [] >>
  imp_res_tac conPropsTheory.do_app_cases >>
  fs [] >>
  rw [] >>
  fs [conSemTheory.do_app_def]
  >- tac
  >- tac
  >- (every_case_tac >>
      imp_res_tac do_eq >>
      fs [] >>
      rw [exhSemTheory.do_app_def, result_rel_cases, conSemTheory.exn_tag_def,
          conSemTheory.prim_exn_def, exhSemTheory.prim_exn_def, v_rel_eqn,
          conSemTheory.Boolv_def, exhSemTheory.Boolv_def] >>
      fs[state_rel_def])
  >- (tac >>
      metis_tac [v_rel_eqn, store_v_distinct, evalPropsTheory.sv_rel_def])
  >- tac
  >- (tac >>
    Cases_on`n < LENGTH s1_exh.refs`>>simp[EL_APPEND1,EL_APPEND2] >>
    strip_tac >> `n = LENGTH s1_exh.refs` by simp[] >> simp[])
  >- ( tac >>
    Cases_on`n' < LENGTH s1_exh.refs`>>simp[EL_APPEND1,EL_APPEND2] >>
    strip_tac >> `n' = LENGTH s1_exh.refs` by simp[] >> simp[])
  >- (tac >>
      metis_tac [v_rel_eqn, store_v_distinct, evalPropsTheory.sv_rel_def])
  >- tac
  >- (tac >>
      metis_tac [v_rel_eqn, store_v_distinct, evalPropsTheory.sv_rel_def])
  >- tac
  >- tac
  >- tac
  >- ( tac >> metis_tac[char_list_to_v] )
  >- ( imp_res_tac v_to_char_list >> tac)
  >- tac
  >- (imp_res_tac v_to_list >>
      rw [exhSemTheory.do_app_def, result_rel_cases, v_rel_eqn] >>
      fs [vs_rel_LIST_REL,state_rel_def])
  >- (tac >>
      full_simp_tac (srw_ss()++ARITH_ss) [])
  >- tac
  >- (tac >>
      rw [LIST_REL_EL_EQN, LENGTH_REPLICATE, EL_REPLICATE] >>
    Cases_on`n' < LENGTH s1_exh.refs`>>simp[EL_APPEND1,EL_APPEND2] >>
    `n' = LENGTH s1_exh.refs` by simp[] >> simp[] >>
      rw [LIST_REL_EL_EQN, LENGTH_REPLICATE, EL_REPLICATE] )
  >- (tac >>
      rw []
      >- (CCONTR_TAC >>
          fs [] >>
          imp_res_tac LIST_REL_LENGTH >>
          full_simp_tac (srw_ss()++ARITH_ss) [])
      >- (CCONTR_TAC >>
          fs [] >>
          imp_res_tac LIST_REL_LENGTH >>
          full_simp_tac (srw_ss()++ARITH_ss) [])
      >- (fs [LIST_REL_EL_EQN] >>
          `Num (ABS i) < LENGTH l'` by decide_tac >>
          res_tac))
  >- (tac >>
      metis_tac [LIST_REL_LENGTH])
  >- (tac >> rw []
      >- (CCONTR_TAC >>
          fs [] >>
          imp_res_tac LIST_REL_LENGTH >>
          full_simp_tac (srw_ss()++ARITH_ss) [])
      >- (CCONTR_TAC >>
          fs [] >>
          imp_res_tac LIST_REL_LENGTH >>
          full_simp_tac (srw_ss()++ARITH_ss) [])
      >- (ASM_REWRITE_TAC [evalPropsTheory.sv_rel_def, vs_rel_LIST_REL] >>
          match_mp_tac EVERY2_LUPDATE_same >>
          fs [] ))
   >- (tac >>
       `l = l'` by metis_tac[evalPropsTheory.sv_rel_def] >>
       fs[])) |> INST_TYPE[alpha|->``:'ffi``];

val do_app = prove(
  ``∀s1 op vs s2 res exh s1_exh vs_exh.
      do_app (s1:'ffi decSem$state) op vs = SOME (s2,res) ∧
      state_rel exh s1 s1_exh ∧
      vs_rel exh vs vs_exh ⇒
      ∃s2_exh res_exh.
        do_app s1_exh op vs_exh = SOME (s2_exh,res_exh) ∧
        result_rel v_rel exh (s2,res) (s2_exh,res_exh)``,
  rpt gen_tac >>
  rw[decSemTheory.do_app_def] >>
  Cases_on`op`>>fs[] >- (
    every_case_tac >> fs[] >>
    first_assum(mp_tac o MATCH_MP (REWRITE_RULE[GSYM AND_IMP_INTRO]do_app_lem)) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    simp[vs_rel_LIST_REL] >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    metis_tac[] ) >>
  simp[exhSemTheory.do_app_def] >>
  fs[LIST_REL_EL_EQN,result_rel_cases] >>
  every_case_tac >> fs[] >> rw[] >> fs[state_rel_def] >>
  fs[LIST_REL_EL_EQN,OPTREL_def,EL_LUPDATE,evalPropsTheory.sv_rel_cases] >>
  rw[] >> metis_tac[NOT_SOME_NONE]);

val do_opapp = prove(
  ``∀vs env e exh vs_exh.
    do_opapp vs = SOME (env,e) ∧
    vs_rel exh vs vs_exh
    ⇒
    ∃exh' env_exh.
      env_rel exh env env_exh ∧
      exh' ⊑ exh ∧
      do_opapp vs_exh = SOME (env_exh,compile_exp exh' e)``,
  rw[conSemTheory.do_opapp_def,exhSemTheory.do_opapp_def] >>
  every_case_tac >> fs[] >> rw[] >>
  TRY (fs[Once v_rel_cases]>>NO_TAC) >>
  fs[Q.SPECL[`exh`,`Closure X Y Z`](CONJUNCT1 v_rel_cases),env_rel_LIST_REL] >>
  fs[Q.SPECL[`exh`,`Recclosure X Y Z`](CONJUNCT1 v_rel_cases),env_rel_LIST_REL] >>
  rw[] >> fs[find_recfun_compile_funs] >> rw[] >>
  fs[compile_funs_map,MAP_MAP_o,combinTheory.o_DEF,UNCURRY,FST_triple,ETA_AX]
  >- metis_tac[SUBMAP_REFL] >>
  simp[exhPropsTheory.build_rec_env_merge,conPropsTheory.build_rec_env_merge] >>
  qexists_tac`exh'`>>simp[] >>
  match_mp_tac EVERY2_APPEND_suff >>
  simp[EVERY2_MAP,UNCURRY] >>
  simp[Once v_rel_cases,compile_funs_map,MAP_EQ_f] >>
  match_mp_tac EVERY2_refl >>
  simp[UNCURRY,env_rel_LIST_REL] >>
  metis_tac[]);

(* compiler correctness *)

val exists_match_def = Define `
  exists_match exh s ps v ⇔
    !env. ?p. MEM p ps ∧ pmatch exh s p v env ≠ No_match`;

val is_unconditional_thm = prove(
  ``∀p a b c d. is_unconditional p ⇒ pmatch a b p c d ≠ No_match``,
  ho_match_mp_tac is_unconditional_ind >>
  Cases >> rw[] >>
  Cases_on`c`>>rw[conSemTheory.pmatch_def]
  >- (
    fs[is_unconditional_def] )
  >- (
    pop_assum mp_tac >>
    rw[Once is_unconditional_def] >>
    every_case_tac >> fs[] >>
    Cases_on`o''`>>rw[conSemTheory.pmatch_def] >>
    fs[PULL_FORALL] >> rfs[EVERY_MEM] >>
    pop_assum mp_tac >>
    map_every qid_spec_tac[`l'`,`a`,`b`,`d`] >>
    Induct_on`l` >> simp[LENGTH_NIL_SYM,conSemTheory.pmatch_def] >>
    rw[] >> Cases_on`l'`>>fs[] >>
    rw[conSemTheory.pmatch_def] >>
    BasicProvers.CASE_TAC >>
    metis_tac[] )
  >- (
    pop_assum mp_tac >>
    rw[Once is_unconditional_def] >>
    BasicProvers.EVERY_CASE_TAC >>
    metis_tac[]))

val is_unconditional_list_thm = prove(
  ``∀l1 l2 a b c. EVERY is_unconditional l1 ⇒ pmatch_list a b l1 l2 c ≠ No_match``,
  Induct >> Cases_on`l2` >> simp[conSemTheory.pmatch_def] >>
  rw[] >>
  BasicProvers.CASE_TAC >>
  metis_tac[is_unconditional_thm])

val get_tags_thm = Q.prove(
  `∀ps t1 t2. get_tags ps t1 = SOME t2 ⇒
      (∀p. MEM p ps ⇒ ∃t x vs left.
             (p = Pcon (SOME (t,x)) vs) ∧ EVERY is_unconditional vs ∧
             lookup (LENGTH vs) t2 = SOME left ∧ t ∉ domain left) ∧
      (∀a tags.
        lookup a t1 = SOME tags ⇒
        ∃left. lookup a t2 = SOME left ∧ domain left ⊆ domain tags ∧
               (∀t. t ∈ domain tags ∧ t ∉ domain left ⇒
                    ∃x vs. MEM (Pcon (SOME (t,x)) vs) ps ∧ EVERY is_unconditional vs ∧
                           LENGTH vs = a))`,
  Induct >> simp[get_tags_def] >>
  Cases >> simp[] >>
  Cases_on`o'`>>simp[]>>
  Cases_on`x`>>simp[]>>
  rpt gen_tac >>
  BasicProvers.CASE_TAC >>
  strip_tac >>
  first_x_assum(fn th=> first_x_assum(mp_tac o MATCH_MP th)) >>
  strip_tac >>
  conj_tac >- (
    gen_tac >> strip_tac >- (
      simp[] >>
      first_x_assum(qspec_then`LENGTH l`mp_tac) >>
      simp[sptreeTheory.lookup_insert] >>
      simp[SUBSET_DEF] >>
      strip_tac >> simp[] >>
      metis_tac[] ) >>
    metis_tac[] ) >>
  rw[] >>
  first_x_assum(qspec_then`a`mp_tac) >>
  simp[sptreeTheory.lookup_insert] >>
  rw[] >- (
    simp[] >> rfs[] >>
    fs[SUBSET_DEF] >>
    metis_tac[] ) >>
  metis_tac[])

val pmatch_Pcon_No_match = prove(
  ``EVERY is_unconditional ps ⇒
    ((pmatch exh s (Pcon (SOME(c,TypeId t)) ps) v env = No_match) ⇔
     ∃cv vs tags max maxv.
       v = Conv (SOME(cv,TypeId t)) vs ∧
       FLOOKUP exh t = SOME tags ∧
       lookup (LENGTH ps) tags = SOME max ∧
       lookup (LENGTH vs) tags = SOME maxv ∧
       c < max ∧ cv < maxv ∧
       (LENGTH ps = LENGTH vs ⇒ c ≠ cv))``,
  Cases_on`v`>>rw[conSemTheory.pmatch_def]>>
  Cases_on`o'`>>simp[conSemTheory.pmatch_def] >>
  PairCases_on`x`>>simp[conSemTheory.pmatch_def]>>
  Cases_on`x1`>>simp[conSemTheory.pmatch_def]>>
  rw[] >> every_case_tac >> rw[] >> fs[] >>
  metis_tac[is_unconditional_list_thm])

val exh_to_exists_match = Q.prove (
  `!exh ps. exhaustive_match exh ps ⇒ !s v. exists_match exh s ps v`,
  rw [exhaustive_match_def, exists_match_def] >- (
    fs[EXISTS_MEM] >>
    metis_tac[is_unconditional_thm] ) >>
  every_case_tac >>
  fs [get_tags_def, conSemTheory.pmatch_def] >> rw[] >>
  imp_res_tac get_tags_thm >>
  Q.PAT_ABBREV_TAC`pp1 = Pcon X l` >>
  Cases_on`v`>>
  TRY(qexists_tac`pp1`>>simp[conSemTheory.pmatch_def,Abbr`pp1`]>>NO_TAC) >>
  srw_tac[boolSimps.DNF_ss][]>>
  simp[Abbr`pp1`,pmatch_Pcon_No_match]>>
  simp[METIS_PROVE[]``a \/ b <=> ~a ==> b``] >>
  strip_tac >>
  BasicProvers.VAR_EQ_TAC >>
  fs[sptreeTheory.lookup_map,sptreeTheory.domain_fromList,PULL_EXISTS] >>
  res_tac >>
  rfs[EVERY_MEM,sptreeTheory.MEM_toList,PULL_EXISTS] >>
  res_tac >> fs[] >> rfs[] >> rw[] >>
  first_assum(match_exists_tac o concl) >>
  simp[conSemTheory.pmatch_def] >>
  Cases_on`x'''`>>simp[conSemTheory.pmatch_def] >>
  rw[] >>
  metis_tac[is_unconditional_list_thm,EVERY_MEM])

fun exists_lift_conj_tac tm =
  CONV_TAC(
    STRIP_BINDER_CONV(SOME existential)
      (lift_conjunct_conv(same_const tm o fst o strip_comb)))

val Boolv_disjoint = LIST_CONJ [
  EVAL``conSem$Boolv T = Boolv F``,
  EVAL``exhSem$Boolv T = Boolv F``]

val s = mk_var("s",
  ``decSem$evaluate`` |> type_of |> strip_fun |> #1 |> el 2
  |> type_subst[alpha |-> ``:'ffi``])

val compile_exp_evaluate = Q.store_thm ("compile_exp_evaluate",
  `(!env ^s es r.
    evaluate env s es = r
    ⇒
    !env_exh s_exh exh'.
      env_rel env.exh env.v env_exh ∧
      state_rel env.exh s s_exh ∧
      exh' ⊑ env.exh ∧
      SND r ≠ Rerr (Rabort Rtype_error)
      ⇒
      ?r_exh.
      result_rel vs_rel env.exh r r_exh ∧
      evaluate env_exh s_exh (compile_exps exh' es) = r_exh) ∧
   (!env ^s v pes err_v r.
    evaluate_match env s v pes err_v = r
    ⇒
    !pes' is_handle env_exh s_exh v_exh exh'.
      env_rel env.exh env.v env_exh ∧
      state_rel env.exh s s_exh ∧
      v_rel env.exh v v_exh ∧
      (is_handle ⇒ err_v = v) ∧
      (¬is_handle ⇒ err_v = Conv (SOME (bind_tag, (TypeExn(Short "Bind")))) []) ∧
      (pes' = add_default is_handle F pes ∨
       exists_match env.exh s.refs (MAP FST pes) v ∧
       pes' = add_default is_handle T pes) ∧
      exh' ⊑ env.exh ∧
      SND r ≠ Rerr (Rabort Rtype_error)
       ⇒
      ?r_exh.
      result_rel vs_rel env.exh r r_exh ∧
      evaluate_match env_exh s_exh v_exh (compile_pes exh' pes') = r_exh)`,
  ho_match_mp_tac decSemTheory.evaluate_ind >>
  (* nil *)
  strip_tac >- (
    rw[exhSemTheory.evaluate_def,compile_exp_def,
       decSemTheory.evaluate_def,result_rel_cases] ) >>
  (* cons *)
  strip_tac >- (
    rw[compile_exps_map] >>
    Q.ISPECL_THEN[`e1`,`e2::es`,`s`]assume_tac(Q.GENL[`s`,`es`,`e`]decPropsTheory.evaluate_cons) >> fs[] >>
    (fn g => valOf(bvk_find_term (K true) split_pair_case_tac (#2 g)) g) >> fs[] >>
    qmatch_assum_rename_tac`_ = (_,r)` >>
    (fn g => valOf(bvk_find_term (K true) split_pair_case_tac (#2 g)) g) >> fs[] >>
    reverse(Cases_on`r`)>>fs[]>-(
      fs[result_rel_cases] >>
      res_tac >> fs[] >>
      rw[Once exhPropsTheory.evaluate_cons]) >>
    qmatch_assum_rename_tac`_ = (_,r)` >>
    Cases_on`r = Rerr (Rabort Rtype_error)`>>fs[] >>
    simp[Once exhPropsTheory.evaluate_cons] >>
    first_x_assum(fn th => first_assum(mp_tac o MATCH_MP(REWRITE_RULE[GSYM AND_IMP_INTRO]th))) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    simp[Once result_rel_cases] >> strip_tac >> simp[] >>
    first_x_assum(fn th => first_assum(mp_tac o MATCH_MP(REWRITE_RULE[GSYM AND_IMP_INTRO]th))) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    rw[result_rel_cases] >> rw[] >>
    metis_tac[EVERY2_APPEND_suff]) >>
  (* Lit *)
  strip_tac >- (
    rw[exhSemTheory.evaluate_def,decSemTheory.evaluate_def,compile_exp_def] ) >>
  (* Raise *)
  strip_tac >- (
    rw[exhSemTheory.evaluate_def,decSemTheory.evaluate_def,compile_exp_def] >>
    first_x_assum(fn th => first_assum(mp_tac o MATCH_MP(REWRITE_RULE[GSYM AND_IMP_INTRO]th))) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    discharge_hyps >- (
      strip_tac >> every_case_tac >> fs[] ) >>
    every_case_tac >> fs[] >>
    imp_res_tac decPropsTheory.evaluate_sing >>
    imp_res_tac exhPropsTheory.evaluate_sing >>
    rw[] ) >>
  (* Handle *)
  strip_tac >- (
    rw[exhSemTheory.evaluate_def,decSemTheory.evaluate_def,compile_exp_def] >>
    first_x_assum(fn th => first_assum(mp_tac o MATCH_MP(REWRITE_RULE[GSYM AND_IMP_INTRO]th))) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    discharge_hyps >- (
      strip_tac >> every_case_tac >> fs[] ) >>
    every_case_tac >> fs[] >> strip_tac >>
    first_x_assum(fn th => first_assum(mp_tac o MATCH_MP(REWRITE_RULE[GSYM AND_IMP_INTRO]th))) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >> rw[] >>
    first_x_assum(match_mp_tac o MP_CANON) >>
    qexists_tac`T`>>simp[add_default_def]>>rw[]>>
    metis_tac[exh_to_exists_match,exhaustive_match_submap] ) >>
  (* Con *)
  strip_tac >- (
    Cases_on`tag`>>(TRY(PairCases_on`x`))>>
    rw[exhSemTheory.evaluate_def,decSemTheory.evaluate_def,compile_exp_def] >>
    first_x_assum(fn th => first_assum(mp_tac o MATCH_MP(REWRITE_RULE[GSYM AND_IMP_INTRO]th))) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    every_case_tac >> fs[compile_exp_def] >>
    fs[compile_exps_map,MAP_REVERSE] >> rw[v_rel_eqn] >>
    metis_tac[EVERY2_REVERSE]) >>
  (* Var_local *)
  strip_tac >- (
    rw[exhSemTheory.evaluate_def,decSemTheory.evaluate_def,compile_exp_def] >>
    fs[env_rel_MAP] >>
    every_case_tac >> fs[] >> rw[] >- (
      imp_res_tac ALOOKUP_FAILS >>
      imp_res_tac ALOOKUP_MEM >>
      metis_tac[MEM_MAP,FST,PAIR] ) >>
    rpt (pop_assum mp_tac) >>
    map_every qid_spec_tac[`env_exh`,`n`,`v`] >>
    Q.SPEC_TAC(`env.v`,`evs`) >>
    Induct>>simp[]>>
    rw[EXISTS_PROD] >> simp[] >>
    Cases_on`env_exh`>>fs[]>>
    Cases_on`h`>>Cases_on`h'`>>fs[]>>
    rw[]>>fs[]>>
    pop_assum mp_tac >> rw[]>>fs[]>>
    metis_tac[]) >>
  (* Var_global *)
  strip_tac >- (
    rw[exhSemTheory.evaluate_def,decSemTheory.evaluate_def,compile_exp_def] >>
    rw[]>>fs[state_rel_def]>> fs[LIST_REL_EL_EQN] >> rfs[] >>
    fs[OPTREL_def,IS_SOME_EXISTS] >>
    metis_tac[NOT_SOME_NONE,SOME_11]) >>
  (* Fun *)
  strip_tac >- (
    rw[exhSemTheory.evaluate_def,decSemTheory.evaluate_def,compile_exp_def] >>
    simp[Once v_rel_cases] >>
    HINT_EXISTS_TAC >> simp[]) >>
  (* App *)
  strip_tac >- (
    rw[exhSemTheory.evaluate_def,decSemTheory.evaluate_def,compile_exp_def] >>
    fs[compile_exps_map,MAP_REVERSE] >>
    first_x_assum(fn th => first_assum(mp_tac o MATCH_MP(REWRITE_RULE[GSYM AND_IMP_INTRO]th))) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    discharge_hyps >- ( every_case_tac >> fs[] ) >>
    strip_tac >>
    every_case_tac >> fs[] >> rfs[] >> rw[] >>
    TRY(fs[state_rel_def]>>NO_TAC) >>
    TRY (
      first_assum(mp_tac o MATCH_MP (ONCE_REWRITE_RULE[GSYM AND_IMP_INTRO]do_opapp)) >>
      imp_res_tac EVERY2_REVERSE >> simp[] >>
      metis_tac[SOME_11,NOT_SOME_NONE,state_rel_dec_clock,PAIR_EQ,PAIR]) >>
    first_assum(mp_tac o MATCH_MP (REWRITE_RULE[GSYM AND_IMP_INTRO] do_app)) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    imp_res_tac EVERY2_REVERSE >> simp[] >>
    metis_tac[SOME_11,NOT_SOME_NONE,result_rel_list_result] ) >>
  (* Mat *)
  strip_tac >- (
    rw[exhSemTheory.evaluate_def,decSemTheory.evaluate_def,compile_exp_def] >>
    first_x_assum(fn th => first_assum(mp_tac o MATCH_MP(REWRITE_RULE[GSYM AND_IMP_INTRO]th))) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    discharge_hyps >- ( every_case_tac >> fs[] ) >>
    strip_tac >>
    every_case_tac >> fs[] >> rfs[] >> rw[] >>
    first_x_assum(fn th => first_assum(mp_tac o MATCH_MP(REWRITE_RULE[GSYM AND_IMP_INTRO]th))) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    imp_res_tac decPropsTheory.evaluate_sing >>
    imp_res_tac exhPropsTheory.evaluate_sing >> fs[] >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    disch_then (match_mp_tac o MP_CANON) >>
    qexists_tac`F` >> simp[] >>
    Cases_on`exhaustive_match exh' (MAP FST pes)`>>simp[] >>
    metis_tac[exhaustive_match_submap,exh_to_exists_match] ) >>
  (* Let *)
  strip_tac >- (
    rw[exhSemTheory.evaluate_def,decSemTheory.evaluate_def,compile_exp_def] >>
    first_x_assum(fn th => first_assum(mp_tac o MATCH_MP(REWRITE_RULE[GSYM AND_IMP_INTRO]th))) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    discharge_hyps >- ( every_case_tac >> fs[] ) >>
    strip_tac >>
    every_case_tac >> fs[] >> rfs[] >> rw[] >>
    imp_res_tac decPropsTheory.evaluate_sing >>
    imp_res_tac exhPropsTheory.evaluate_sing >> fs[] >>
    first_x_assum(match_mp_tac o MP_CANON) >>
    fs[env_rel_LIST_REL,libTheory.opt_bind_def] >>
    BasicProvers.CASE_TAC >> fs[] ) >>
  (* Letrec *)
  strip_tac >- (
    rw[exhSemTheory.evaluate_def,decSemTheory.evaluate_def,compile_exp_def] >>
    fs[compile_funs_map,MAP_MAP_o,o_DEF,UNCURRY,ETA_AX] >>
    first_x_assum match_mp_tac >> simp[] >>
    fs[env_rel_LIST_REL,conPropsTheory.build_rec_env_merge,exhPropsTheory.build_rec_env_merge] >>
    match_mp_tac EVERY2_APPEND_suff >>
    simp[EVERY2_MAP] >>
    match_mp_tac EVERY2_refl >>
    simp[FORALL_PROD] >>
    simp[Once v_rel_cases,compile_funs_map,MAP_EQ_f,FORALL_PROD,env_rel_LIST_REL] >>
    metis_tac[] ) >>
  (* Extend_global *)
  strip_tac >- (
    rw[exhSemTheory.evaluate_def,decSemTheory.evaluate_def,compile_exp_def] >>
    fs[state_rel_def] >>
    match_mp_tac EVERY2_APPEND_suff >>
    simp[] >>
    simp[EVERY2_EVERY,EVERY_MEM,MEM_ZIP,PULL_EXISTS,optionTheory.OPTREL_def] ) >>
  (* match nil *)
  strip_tac >- (
    simp[exhSemTheory.evaluate_def,decSemTheory.evaluate_def,compile_exp_def] >>
    rw[add_default_def] >>
    simp[exhSemTheory.evaluate_def,compile_exp_def,
         exhSemTheory.pat_bindings_def,compile_pat_def,exhSemTheory.pmatch_def] >>
    fs[exists_match_def] ) >>
  (* match cons *)
  strip_tac >- (
    simp[exhSemTheory.evaluate_def,decSemTheory.evaluate_def,compile_exp_def] >>
    rpt gen_tac >> strip_tac >> rpt gen_tac >>
    IF_CASES_TAC >> fs[] >>
    simp[GSYM AND_IMP_INTRO] >>
    ntac 5 strip_tac >>
    `LIST_REL (sv_rel (v_rel env.exh)) s.refs s_exh.refs` by fs[state_rel_def] >>
    BasicProvers.CASE_TAC >> fs[] >>
    imp_res_tac (CONJUNCT1 pmatch) >> fs[match_result_nomatch] >>
    rw[add_default_def] >> rw[compile_exp_def,exhSemTheory.evaluate_def] >>
    fs[pat_bindings] >> rw[] >> fs[] >>
    TRY (
      first_x_assum(match_mp_tac o MP_CANON) >> simp[] >>
      rw[add_default_def] >>
      qexists_tac`T`>>fs[] >>
      fs[exists_match_def] >>
      metis_tac[conPropsTheory.pmatch_any_no_match]) >>
    TRY (
      first_x_assum(match_mp_tac o MP_CANON) >> simp[] >>
      rw[add_default_def] >>
      qexists_tac`F`>>fs[] >>
      fs[exists_match_def] >>
      metis_tac[conPropsTheory.pmatch_any_no_match]) >>
    Cases_on`pmatch s_exh.refs (compile_pat p) v_exh env_exh`>>
    fs[match_result_rel_def]));

val compile_exp_semantics = Q.store_thm("compile_exp_semantics",
  `semantics env st es ≠ Fail ∧
   env_rel env.exh env.v envh ∧
   state_rel env.exh st sth
  ⇒
   semantics envh sth
     (compile_exps env.exh es) =
   semantics env st es`,
  simp[decSemTheory.semantics_def] >>
  IF_CASES_TAC >> fs[] >>
  DEEP_INTRO_TAC some_intro >> simp[] >>
  conj_tac >- (
    rw[] >>
    simp[exhSemTheory.semantics_def] >>
    IF_CASES_TAC >> fs[] >- (
      rator_x_assum`decSem$evaluate`kall_tac >>
      last_x_assum(qspec_then`k'`mp_tac)>>simp[] >>
      (fn g => subterm (fn tm => Cases_on`^(assert(has_pair_type)tm)`) (#2 g) g) >>
      spose_not_then strip_assume_tac >>
      drule (CONJUNCT1 compile_exp_evaluate) >>
      disch_then drule >>
      imp_res_tac state_rel_with_clock >>
      first_x_assum(qspec_then`k'`strip_assume_tac) >>
      disch_then drule >>
      disch_then(qspec_then`env.exh`mp_tac)>>
      discharge_hyps >- simp[] >>
      discharge_hyps >- fs[] >> strip_tac >>
      fs[result_rel_cases] >> fs[]) >>
    DEEP_INTRO_TAC some_intro >> simp[] >>
    conj_tac >- (
      rw[] >>
      qmatch_assum_abbrev_tac`decSem$evaluate env ss es = _` >>
      qmatch_assum_abbrev_tac`exhSem$evaluate bnv bs be = _` >>
      qispl_then[`env`,`ss`,`es`]mp_tac (CONJUNCT1 decPropsTheory.evaluate_add_to_clock_io_events_mono) >>
      qispl_then[`bnv`,`bs`,`be`]mp_tac (CONJUNCT1 exhPropsTheory.evaluate_add_to_clock_io_events_mono) >>
      simp[Abbr`bs`,Abbr`ss`] >>
      disch_then(qspec_then`k`strip_assume_tac) >>
      disch_then(qspec_then`k'`strip_assume_tac) >>
      Cases_on`s.ffi.final_event`>>fs[]>-(
        Cases_on`s'.ffi.final_event`>>fs[]>-(
          unabbrev_all_tac >>
          drule (CONJUNCT1 compile_exp_evaluate) >>
          disch_then drule >>
          imp_res_tac state_rel_with_clock >>
          first_x_assum(qspec_then`k`strip_assume_tac) >>
          disch_then drule >>
          disch_then(qspec_then`env.exh`mp_tac)>>
          discharge_hyps >- simp[] >>
          discharge_hyps >- fs[] >>
          CONV_TAC(LAND_CONV(SIMP_CONV std_ss [EXISTS_PROD])) >>
          strip_tac >>
          drule (GEN_ALL (CONJUNCT1 exhPropsTheory.evaluate_add_to_clock)) >>
          simp[RIGHT_FORALL_IMP_THM] >>
          discharge_hyps >- (strip_tac >> fs[result_rel_cases]) >>
          disch_then(qspec_then`k'`mp_tac)>>simp[]>>
          rator_x_assum`exhSem$evaluate`mp_tac >>
          drule (GEN_ALL (CONJUNCT1 exhPropsTheory.evaluate_add_to_clock)) >>
          simp[] >>
          disch_then(qspec_then`k`mp_tac)>>simp[]>>
          ntac 3 strip_tac >> rveq >> fs[] >>
          fs[state_component_equality,result_rel_cases,state_rel_def] >> rfs[]) >>
        first_assum(subterm (fn tm => Cases_on`^(assert has_pair_type tm)`) o concl) >> fs[] >>
        unabbrev_all_tac >>
        drule (CONJUNCT1 compile_exp_evaluate) >>
        disch_then drule >>
        imp_res_tac state_rel_with_clock >>
        first_x_assum(qspec_then`k'+k`strip_assume_tac) >>
        disch_then drule >>
        disch_then(qspec_then`env.exh`mp_tac)>>
        discharge_hyps >- simp[] >>
        discharge_hyps >- (
          last_x_assum(qspec_then`k+k'`mp_tac)>>
          rpt strip_tac >> fsrw_tac[ARITH_ss][] >> rfs[] ) >>
        CONV_TAC(LAND_CONV(SIMP_CONV(srw_ss())[EXISTS_PROD])) >>
        strip_tac >>
        rator_x_assum`decSem$evaluate`mp_tac >>
        drule (GEN_ALL (CONJUNCT1 decPropsTheory.evaluate_add_to_clock)) >>
        CONV_TAC(LAND_CONV(SIMP_CONV(srw_ss())[RIGHT_FORALL_IMP_THM])) >>
        discharge_hyps >- (strip_tac >> fs[]) >>
        disch_then(qspec_then`k'`mp_tac)>>simp[] >>
        strip_tac >>
        spose_not_then strip_assume_tac >>
        rveq >>
        fsrw_tac[ARITH_ss][state_rel_def,result_rel_cases] >> rfs[] >> fs[]) >>
      first_assum(subterm (fn tm => Cases_on`^(assert has_pair_type tm)`) o concl) >> fs[] >>
      unabbrev_all_tac >>
      drule (CONJUNCT1 compile_exp_evaluate) >>
      disch_then drule >>
      imp_res_tac state_rel_with_clock >>
      first_x_assum(qspec_then`k'+k`strip_assume_tac) >>
      disch_then drule >>
      disch_then(qspec_then`env.exh`mp_tac)>>
      discharge_hyps >- simp[] >>
      discharge_hyps >- (
        last_x_assum(qspec_then`k+k'`mp_tac)>>
        rpt strip_tac >> fsrw_tac[ARITH_ss][] >> rfs[] ) >>
      CONV_TAC(LAND_CONV(SIMP_CONV(srw_ss())[EXISTS_PROD])) >>
      strip_tac >> rveq >>
      reverse(Cases_on`s'.ffi.final_event`)>>fs[]>>rfs[]>- (
        fsrw_tac[ARITH_ss][] >> rfs[state_rel_def,result_rel_cases] >> fs[] >> rfs[]) >>
      rator_x_assum`exhSem$evaluate`mp_tac >>
      drule (GEN_ALL(CONJUNCT1 exhPropsTheory.evaluate_add_to_clock)) >>
      CONV_TAC(LAND_CONV(SIMP_CONV(srw_ss())[RIGHT_FORALL_IMP_THM])) >>
      discharge_hyps >- fs[] >>
      disch_then(qspec_then`k`mp_tac)>>simp[] >>
      rpt strip_tac >> spose_not_then strip_assume_tac >>
      fsrw_tac[ARITH_ss][state_rel_def,result_rel_cases,state_component_equality] >> fs[] >> rfs[]) >>
    drule (CONJUNCT1 compile_exp_evaluate) >> simp[] >>
    disch_then drule >>
    imp_res_tac state_rel_with_clock >>
    first_x_assum(qspec_then`k`strip_assume_tac) >>
    disch_then drule >>
    disch_then(qspec_then`env.exh`mp_tac)>>
    discharge_hyps >- simp[] >>
    discharge_hyps >- (
      last_x_assum(qspec_then`k`mp_tac)>>
      fs[] >> rpt strip_tac >> fs[] ) >>
    strip_tac >>
    srw_tac[QUANT_INST_ss[pair_default_qp]][] >>
    qexists_tac`k`>>simp[] >>
    fs[state_rel_def,result_rel_cases] >>
    CASE_TAC >> fs[]) >>
  strip_tac >>
  simp[exhSemTheory.semantics_def] >>
  IF_CASES_TAC >> fs[] >- (
    last_x_assum(qspec_then`k`strip_assume_tac) >>
    qmatch_assum_abbrev_tac`SND p ≠ _` >>
    Cases_on`p`>>fs[markerTheory.Abbrev_def] >>
    pop_assum(assume_tac o SYM) >>
    spose_not_then strip_assume_tac >>
    first_assum(mp_tac o MATCH_MP (CONJUNCT1 compile_exp_evaluate)) >>
    simp[] >>
    first_assum(match_exists_tac o concl) >> simp[] >>
    imp_res_tac state_rel_with_clock >>
    first_x_assum(qspec_then`k`strip_assume_tac) >>
    first_assum(match_exists_tac o concl) >> simp[] >>
    qexists_tac`env.exh`>>simp[] >>
    rw[result_rel_cases] >>
    spose_not_then strip_assume_tac >> fs[]) >>
  strip_tac >>
  DEEP_INTRO_TAC some_intro >> simp[] >>
  conj_tac >- (
    spose_not_then strip_assume_tac >>
    last_x_assum(qspec_then`k`mp_tac) >>
    (fn g => subterm (fn tm => Cases_on`^(assert (can dest_prod o type_of) tm)` g) (#2 g)) >>
    strip_tac >>
    last_x_assum(qspec_then`k`mp_tac)>>simp[] >>
    drule(CONJUNCT1 compile_exp_evaluate) >>
    disch_then drule >>
    imp_res_tac state_rel_with_clock >>
    first_x_assum(qspec_then`k`strip_assume_tac) >>
    disch_then drule >>
    disch_then(qspec_then`env.exh`mp_tac)>>
    discharge_hyps >- simp[] >>
    discharge_hyps >- fs[] >> strip_tac >>
    fs[result_rel_cases,state_rel_def] >> rveq >> fs[] >>
    CASE_TAC >> fs[]) >>
  rpt strip_tac >>
  rpt (AP_TERM_TAC ORELSE AP_THM_TAC) >>
  simp[FUN_EQ_THM] >> gen_tac >>
  rpt (AP_TERM_TAC ORELSE AP_THM_TAC) >>
  specl_args_of_then``decSem$evaluate``(CONJUNCT1 compile_exp_evaluate) mp_tac >>
  simp[] >>
  disch_then(fn th => first_assum (mp_tac o MATCH_MP (REWRITE_RULE[GSYM AND_IMP_INTRO]th))) >>
  imp_res_tac state_rel_with_clock >>
  first_x_assum(qspec_then`k`strip_assume_tac) >>
  disch_then(fn th => first_assum (mp_tac o MATCH_MP (REWRITE_RULE[GSYM AND_IMP_INTRO]th))) >>
  disch_then(qspec_then`env.exh`mp_tac) >> simp[] >>
  rw[result_rel_cases] >> rw[] >>
  fs[state_rel_def])

val _ = export_theory ();