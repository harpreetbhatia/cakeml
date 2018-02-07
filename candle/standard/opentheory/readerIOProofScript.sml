open preamble
     readerTheory readerProofTheory
     readerIOTheory
     holKernelTheory holKernelProofTheory
     ml_monadBaseTheory
     TextIOProofTheory CommandLineProofTheory

val _ = new_theory "readerIOProof"

(* ------------------------------------------------------------------------- *)
(* Wrappers are ok                                                           *)
(* ------------------------------------------------------------------------- *)

val readLine_wrap_thm = Q.store_thm("readLine_wrap_thm",
  `READER_STATE defs s /\
   STATE defs refs /\
   readLine_wrap l s refs = (res, refs')
   ==>
   ?ds x.
     res = Success x /\
     STATE (ds ++ defs) refs' /\
     !s. x = INR s ==> READER_STATE (ds ++ defs) s`,
  rw [readLine_wrap_def, handle_Fail_def, st_ex_bind_def, st_ex_return_def,
      case_eq_thms]
  >- (qexists_tac `[]` \\ fs [])
  \\ fs []
  \\ metis_tac [readLine_thm]);

val init_reader_wrap_thm = Q.store_thm("init_reader_wrap_thm",
  `init_reader_wrap () init_refs = (res, refs')
   ==>
   ?defs x.
     res = Success x /\
     STATE defs refs'`,
  rw [init_reader_wrap_def, handle_Fail_def, st_ex_bind_def, st_ex_return_def,
      case_eq_thms] \\ fs []
  \\ metis_tac [init_reader_ok]);

(* ------------------------------------------------------------------------- *)
(* Monadic I/O reader preserves invariants                                   *)
(* ------------------------------------------------------------------------- *)

val readLines_thm = Q.store_thm("readLines_thm",
  `!s lines res st st1 defs.
     STATE defs st.holrefs /\
     READER_STATE defs s /\
     readLines s lines st = (res, st1)
     ==>
     ?ds x.
       res = Success () /\
       STATE (ds ++ defs) st1.holrefs`,
  recInduct readLines_ind \\ rw [] \\ pop_assum mp_tac
  \\ once_rewrite_tac [readLines_def] \\ fs [st_ex_return_def, st_ex_bind_def]
  \\ fs [liftM_def]
  \\ CASE_TAC \\ fs []
  >-
   (rw [] \\ qexists_tac `[]`
    \\ fs [ print_def, state_refs_component_equality])
  \\ TOP_CASE_TAC
  \\ pairarg_tac \\ fs [] \\ rveq
  \\ reverse every_case_tac \\ fs [] \\ TRY (pairarg_tac \\ fs []) \\ rw []
  >- (imp_res_tac readLine_wrap_thm \\ fs [])
  \\ drule (GEN_ALL readLine_wrap_thm)
  \\ rpt (disch_then drule) \\ rw []
  \\ fs [readLine_wrap_def, handle_Fail_def, st_ex_return_def,
         st_ex_bind_def, case_eq_thms]
  \\ rw [] \\ fs [] \\ rfs [] \\ fs [case_eq_thms] \\ rw [] \\ fs []
  \\ fs [bool_case_eq, COND_RATOR, case_eq_thms] \\ rw []
  \\ drule (GEN_ALL next_line_thm) \\ rw []
  \\ `st with holrefs := st.holrefs = st` by fs [state_refs_component_equality] \\ fs [] \\ rw []
  \\ fs [state_refs_component_equality]
  >-
   (first_x_assum drule
    \\ rpt (disch_then drule)
    \\ rw []
    \\ asm_exists_tac \\ fs [])
  >-
   (qmatch_asmsub_abbrev_tac `readLines _ _ c1`
    \\ `STATE (ds++defs) c1.holrefs` by fs [Abbr `c1`]
    \\ first_x_assum drule
    \\ rpt (disch_then drule) \\ rw []
    \\ metis_tac [])
  \\ fs [liftM_def, print_err_def] \\ rw []
  \\ asm_exists_tac \\ fs []);

(* TODO move *)
val READER_STATE_init_state = Q.store_thm("READER_STATE_init_state[simp]",
  `READER_STATE defs init_state`,
  rw [READER_STATE_def, init_state_def, STATE_def, lookup_def]);

val readMain_thm = Q.store_thm("readMain_thm",
  `readMain () (c with holrefs := init_refs) = (res, c')
   ==>
   res = Success () /\
   ?ds. STATE ds c'.holrefs`,
  rw [readMain_def, st_ex_bind_def, st_ex_return_def, case_eq_thms,
      arguments_def, inputLinesFrom_def, print_err_def, print_def, bool_case_eq,
      COND_RATOR, liftM_def, readFile_def]
  \\ every_case_tac \\ fs [] \\ rw []
  \\ rpt (pairarg_tac \\ fs []) \\ rw []
  \\ imp_res_tac init_reader_wrap_thm \\ fs []
  \\ TRY
   (rw [STATE_def, CONTEXT_def]
    \\ EVAL_TAC \\ fs []
    \\ NO_TAC)
  \\ TRY
    (qmatch_asmsub_abbrev_tac `readLines _ ls c1`
    \\ `STATE defs c1.holrefs` by fs [Abbr`c1`]
    \\ drule (GEN_ALL readLines_thm)
    \\ disch_then (qspecl_then [`init_state`,`ls`] mp_tac) \\ fs [] \\ rw [])
  \\ asm_exists_tac \\ fs []);

(* ------------------------------------------------------------------------- *)
(* Monadic I/O reader satisfies I/O specification                            *)
(* ------------------------------------------------------------------------- *)

val readLine_wrap_correct = Q.store_thm("readLine_wrap_correct",
  `readLine_wrap line s refs = (res, refs_out) /\
   process_line s refs line = res_p
   ==>
   case res of
     Success (INL s) (* Error *) => res_p = (INR s, refs_out)
   | Success (INR s) (* Ok *)    => res_p = (INL s, refs_out)
   | _ => F (* Does not happen *)`,
  rw [readLine_wrap_def, handle_Fail_def, st_ex_bind_def, st_ex_return_def,
      process_line_def, case_eq_thms] \\ fs []);

val readLine_EQ = Q.store_thm("readLine_EQ",
  `readLine_wrap line s refs = (res1, t1) /\
   ~invalid_line line /\
   readLine (fix_fun_typ (str_prefix line)) s refs = (res2, t2)
   ==>
   t1 = t2 /\
   case res1 of
     Success (INL e) => res2 = Failure (Fail e)
   | Success (INR s) => res2 = Success s
   | _ => F`,
  rw [readLine_wrap_def, st_ex_bind_def, st_ex_return_def, handle_Fail_def,
      case_eq_thms] \\ fs []);

val readLine_wrap_invalid_line = Q.store_thm("readLine_wrap_invalid_line",
  `invalid_line h ==> readLine_wrap h s c = (Success (INR s), c)`,
  rw [readLine_wrap_def, st_ex_return_def]);

val readLines_EQ = Q.store_thm("readLines_EQ",
  `!s line c res1 c_out res2 refs.
     readLines s line c = (res1, c_out) /\
     readLines line s c.holrefs = (res2, refs)
     ==>
     refs = c_out.holrefs /\
     res1 = Success () /\
     case res2 of
       Success (s,_) => c_out.stdio = add_stdout c.stdio (msg_success s)
     | Failure (Fail e) => c_out.stdio = add_stderr c.stdio e
     | _ => F`,
  recInduct readLines_ind \\ rw []
  \\ ntac 2 (pop_assum mp_tac)
  \\ once_rewrite_tac [readLines_def, readerTheory.readLines_def]
  \\ CASE_TAC \\ fs [st_ex_bind_def, st_ex_return_def, handle_Fail_def,
                     raise_Fail_def]
  \\ TRY (rw [print_def, liftM_def] \\ rw [] \\ NO_TAC)
  \\ rw [case_eq_thms, bool_case_eq, COND_RATOR]
  \\ every_case_tac \\ fs [] \\ rw []
  \\ fs [liftM_def, print_err_def]
  \\ rpt (pairarg_tac \\ fs []) \\ rw []
  \\ TRY (qpat_x_assum `(_,_) = _` (assume_tac o GSYM))
  \\ imp_res_tac readLine_wrap_invalid_line \\ fs [] \\ rw []
  \\ imp_res_tac readLine_EQ \\ fs [] \\ rw []
  \\ first_x_assum drule \\ simp []);

val readFile_correct = Q.store_thm("readFile_correct",
  `readFile fname c = (res, c_out) /\
   read_file c.stdio c.holrefs fname = (fs, refs)
   ==>
   res = Success () /\ fs = c_out.stdio /\ refs = c_out.holrefs`,
  rw [readFile_def, read_file_def, st_ex_bind_def, st_ex_return_def,
      case_eq_thms]
  \\ every_case_tac \\ fs []
  \\ fs [liftM_def, print_err_def, print_def, inputLinesFrom_def] \\ rw []
  \\ rename1 `readLines lines init_state`
  \\ imp_res_tac readLines_EQ \\ fs [] \\ rw [] \\ rfs [])

val readMain_correct = Q.store_thm ("readMain_correct",
  `readMain () c = (res, c_out) /\
   reader_main c.stdio c.holrefs (TL c.cl) = fs
   ==>
   res = Success () /\ fs = c_out.stdio`,
  rw [readMain_def, st_ex_bind_def, case_eq_thms]
  \\ every_case_tac \\ fs [] \\ rw []
  \\ fs [liftM_def, print_err_def, arguments_def, init_reader_wrap_def,
         handle_Fail_def, st_ex_bind_def, st_ex_return_def, ELIM_UNCURRY]
  \\ rw []
  \\ every_case_tac \\ fs [] \\ rw []
  \\ fs [reader_main_def]
  \\ qmatch_asmsub_abbrev_tac `readFile h c'`
  \\ Cases_on `read_file c'.stdio c'.holrefs h`
  \\ `r = c'.holrefs /\ c.stdio = c'.stdio` by fs [Abbr`c'`] \\ fs []
  \\ imp_res_tac readFile_correct \\ rw []);

(* ------------------------------------------------------------------------- *)
(* Preserving the commandline is crucial                                     *)
(* ------------------------------------------------------------------------- *)

val readLines_COMMANDLINE_pres = Q.store_thm("readLines_COMMANDLINE_pres",
  `!s line sr res tr.
     readLines s line sr = (res, tr)
     ==>
     tr.cl = sr.cl`,
  recInduct readLines_ind \\ rw []
  \\ pop_assum mp_tac \\ once_rewrite_tac [readLines_def]
  \\ fs [liftM_def, print_def]
  \\ CASE_TAC \\ fs [] \\ rw [] \\ fs []
  \\ fs [st_ex_bind_def]
  \\ every_case_tac \\ fs []
  \\ rpt (pairarg_tac \\ fs []) \\ rw []
  \\ first_x_assum drule \\ rw []);

val readMain_COMMANDLINE_pres  = Q.store_thm("readMain_COMMANDLINE_pres",
  `readMain () c = (res, d)
   ==>
   c.cl = d.cl`,
  rw [readMain_def, st_ex_bind_def, st_ex_return_def, case_eq_thms, readFile_def]
  \\ every_case_tac \\ fs []
  \\ fs [liftM_def, arguments_def, print_err_def, UNCURRY] \\ rw []
  \\ imp_res_tac readLines_COMMANDLINE_pres \\ fs []);

val _ = export_theory ();

