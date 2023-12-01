Require Import ssreflect ssrbool Eqdep_dec.
From Equations Require Import Equations. 
From MetaCoq.Utils Require Import All_Forall MCSquash MCList utils.
From MetaCoq.Common Require Import Transform config Kernames.
From MetaCoq.PCUIC Require Import PCUICAst PCUICTyping PCUICFirstorder PCUICCasesHelper BDStrengthening PCUICCumulativity PCUICProgram.
From MetaCoq.Erasure Require Import EWcbvEval EWcbvEvalNamed.
From MetaCoq.SafeChecker Require Import PCUICErrors PCUICWfEnv PCUICWfEnvImpl.

From Malfunction Require Import Malfunction Interpreter SemanticsSpec utils_array 
  Compile RealizabilitySemantics Pipeline.

Require Import ZArith Array.PArray List String Floats Lia Bool.
Import ListNotations.
From MetaCoq.Utils Require Import bytestring.


Section firstorder.

  Context {Σb : list (kername * bool)}.

  Definition CoqType_to_camlType_oneind_type n k decl_type :
    is_true (@firstorder_type Σb n k decl_type) -> camlType.
  Proof.
    unfold firstorder_type. destruct (fst _).
    all: try solve [inversion 1].
    (* case of tRel with a valid index *)
    - intro; exact (Rel (n - S (n0-k))).  (* n0 - k *)  
    (* case of tInd where Σb is saying that inductive_mind is first order *)
    - intro; destruct ind. exact (Adt inductive_mind inductive_ind []).
  Defined.
  

(*  MetaCoq Quote Recursively nat. *)

  Fixpoint CoqType_to_camlType_ind_ctor n m cstr :
    is_true
    (alli
       (fun (k : nat) '{| decl_type := t |} =>
        @firstorder_type Σb m k t) n cstr) -> list camlType. 
  Proof. 
    destruct cstr; cbn; intros. 
    (* no more arguments *)
    * exact [].
    * apply andb_and in H. destruct H. destruct c.
    (* we convert the type of the first type of the constructor *)
      apply CoqType_to_camlType_oneind_type in H.
      refine (H :: _).
    (* we recursively convert *)
      exact (CoqType_to_camlType_ind_ctor _ _ _ H0).
  Defined. 

  Fixpoint CoqType_to_camlType_ind_ctors mind ind_ctors : 
    ind_params mind = [] -> 
    is_true (forallb (@firstorder_con Σb mind) ind_ctors) -> list (list camlType).
  Proof. 
    destruct ind_ctors; intros Hparam H.
    (* no more constructor *)
    - exact [].
    (* a :: ind_ctors constructors *)
    - cbn in H. apply andb_and in H. destruct H. 
      refine (_ :: CoqType_to_camlType_ind_ctors _ _ Hparam H0). clear H0.
      destruct c. unfold firstorder_con in H. cbn in H.
      eapply CoqType_to_camlType_ind_ctor; eauto.     
  Defined. 

  Definition CoqType_to_camlType_oneind mind ind : 
    ind_params mind = [] -> 
    is_true (@firstorder_oneind Σb mind ind) -> list (list camlType).
  Proof.
    destruct ind. intros Hparam H. apply andb_and in H.
    destruct H as [H _]. cbn in *. clear -H Hparam.
    eapply CoqType_to_camlType_ind_ctors; eauto. 
  Defined.

  Lemma bool_irr b (H H' : is_true b) : H = H'.
    destruct b; [| inversion H].
    assert (H = eq_refl).
    eapply (K_dec (fun H => H = eq_refl)); eauto.
    etransitivity; eauto. 
    eapply (K_dec (fun H => eq_refl = H)); eauto.
    Unshelve. all: cbn; eauto. 
    all: intros b b'; pose (Coq.Bool.Bool.bool_dec b b'); intuition. 
  Qed.

  Lemma CoqType_to_camlType_oneind_type_fo n k decl_type Hfo :
    let T := CoqType_to_camlType_oneind_type n k decl_type Hfo in
    is_true (negb (isArrow T)).
  Proof.
    unfold CoqType_to_camlType_oneind_type.
    unfold firstorder_type in Hfo.
    set (fst (PCUICAstUtils.decompose_app decl_type)) in *.
    destruct t; inversion Hfo; cbn; eauto. 
    now destruct ind.
  Qed.     

  Lemma CoqType_to_camlType_oneind_fo mind ind Hparam Hfo larg T : 
    In larg (CoqType_to_camlType_oneind mind ind Hparam Hfo) -> 
    In T larg -> is_true (negb (isArrow T)).
  Proof. 
    destruct mind, ind. revert Hfo. induction ind_ctors0; intros Hfo Hlarg HT.
    - cbn in *; destruct andb_and. destruct (a Hfo). destruct (in_nil Hlarg).
    - cbn in Hlarg. destruct andb_and. destruct (a0 Hfo). 
      destruct andb_and. destruct (a1 i0). destruct a.
      unfold In in Hlarg. destruct Hlarg.
      2: { eapply IHind_ctors0; eauto. cbn. destruct andb_and.
            destruct (a _). rewrite (bool_irr _ i6 i4). eauto.
            Unshelve.
            cbn. apply andb_and. split; cbn; eauto. }
      cbn in Hparam, i3. rewrite Hparam in i3, H. rewrite app_nil_r in i3, H.
      clear - i3 HT H. set (rev cstr_args0) in *. rewrite <- H in HT. revert T HT. clear H. 
      set (Datatypes.length ind_bodies0) in *. revert i3. generalize n 0. clear.
      induction l; cbn; intros; [inversion HT|].
      destruct andb_and. destruct (a0 i3). destruct a.
      unfold In in HT. destruct HT.
      + rewrite <- H; eapply CoqType_to_camlType_oneind_type_fo; eauto.
      + eapply IHl. eauto.
  Qed.    

  (* The following function morally do (map CoqType_to_camlType_oneind) while passing 
  the proof that everything is first order *)

  Fixpoint CoqType_to_camlType_fix ind_bodies0 
    ind_finite0 
    ind_params0 ind_npars0 ind_universes0 
    ind_variance0 {struct ind_bodies0}: 
  ind_params0 = [] -> 
  forall ind_bodies1 : list one_inductive_body,
  is_true
    (forallb
     (@firstorder_oneind Σb
        {|
          Erasure.P.PCUICEnvironment.ind_finite := ind_finite0;
          Erasure.P.PCUICEnvironment.ind_npars := ind_npars0;
          Erasure.P.PCUICEnvironment.ind_params := ind_params0;
          Erasure.P.PCUICEnvironment.ind_bodies := ind_bodies1;
          Erasure.P.PCUICEnvironment.ind_universes := ind_universes0;
          Erasure.P.PCUICEnvironment.ind_variance := ind_variance0
        |}) ind_bodies0) -> list (list (list camlType)).
  Proof.
    destruct ind_bodies0; cbn in *; intros.
    - exact [].
    - refine (CoqType_to_camlType_oneind _ _ _ _ :: CoqType_to_camlType_fix _ _ _ _ _ _ _ _ _); eauto. 
      2-3: unfold firstorder_oneind, firstorder_con; apply andb_and in H0; destruct H0; eauto.
      eauto.
  Defined.   

  Definition CoqType_to_camlType' mind : 
    ind_params mind = [] -> 
    is_true (forallb (@firstorder_oneind Σb mind) (ind_bodies mind)) -> 
    list (list (list camlType)).
  Proof.
    intros Hparam. destruct mind; unshelve eapply CoqType_to_camlType_fix; eauto.
  Defined.

  Lemma CoqType_to_camlType'_fo mind Hparam Hfo lind larg T : 
    In lind (CoqType_to_camlType' mind Hparam Hfo) -> 
    In larg lind ->
    In T larg -> is_true (negb (isArrow T)).
  Proof.
    destruct mind. cbn in Hparam. unfold CoqType_to_camlType'. cbn in *.
    revert Hfo. 
    enough (forall ind_bodies1
    (Hfo : is_true
            (forallb
               (firstorder_oneind
                  {|
                    Erasure.P.PCUICEnvironment.ind_finite :=
                      ind_finite0;
                    Erasure.P.PCUICEnvironment.ind_npars := ind_npars0;
                    Erasure.P.PCUICEnvironment.ind_params :=
                      ind_params0;
                    Erasure.P.PCUICEnvironment.ind_bodies :=
                      ind_bodies1;
                    Erasure.P.PCUICEnvironment.ind_universes :=
                      ind_universes0;
                    Erasure.P.PCUICEnvironment.ind_variance :=
                      ind_variance0
                  |}) ind_bodies0)),
  In lind
    (CoqType_to_camlType_fix ind_bodies0 ind_finite0 ind_params0
       ind_npars0 ind_universes0 ind_variance0 Hparam ind_bodies1 Hfo) ->
  In larg lind -> In T larg -> is_true (negb (isArrow T))).
  eapply H; eauto. 
  induction ind_bodies0; cbn in * ; [now intros |].   
  intros bodies1 Hfo Hlind Hlarg HT. unfold In in Hlind. destruct Hlind.
    - rewrite <- H in Hlarg. eapply CoqType_to_camlType_oneind_fo; eauto.
    - eapply IHind_bodies0; eauto.
  Qed. 

  Lemma CoqType_to_camlType'_fo_alt T1 T2 Ts mind ind Hparam Hfo:
    In Ts
       (nth ind (CoqType_to_camlType'
           mind Hparam Hfo) []) -> ~ In (T1 → T2) Ts.
  Proof.
    intros H H0. 
    epose proof (CoqType_to_camlType'_fo _ _ _ _ _ _ _ _ H0).
    now cbn in H1. Unshelve. all:eauto.  
    case_eq (Nat.ltb ind (List.length (CoqType_to_camlType' mind
    Hparam Hfo))); intro Hleq.
    - apply nth_In. apply leb_complete in Hleq. lia. 
    - apply leb_complete_conv in Hleq. 
      assert (Datatypes.length (CoqType_to_camlType' mind Hparam Hfo) <= ind) by lia.
      pose proof (nth_overflow _ [] H1).
      rewrite H2 in H. destruct (in_nil H).
  Qed.  

  Lemma CoqType_to_camlType'_length mind Hparam Hfo :
    List.length (CoqType_to_camlType' mind Hparam Hfo) 
    = List.length (ind_bodies mind).
  Proof.
    destruct mind. cbn in *. revert Hfo.
    enough (forall ind_bodies1
      (Hfo : is_true
            (forallb
               (firstorder_oneind
                  {|
                    Erasure.P.PCUICEnvironment.ind_finite :=
                      ind_finite0;
                    Erasure.P.PCUICEnvironment.ind_npars :=
                      ind_npars0;
                    Erasure.P.PCUICEnvironment.ind_params :=
                      ind_params0;
                    Erasure.P.PCUICEnvironment.ind_bodies :=
                      ind_bodies1;
                    Erasure.P.PCUICEnvironment.ind_universes :=
                      ind_universes0;
                    Erasure.P.PCUICEnvironment.ind_variance :=
                      ind_variance0
                  |}) ind_bodies0)),
    #|CoqType_to_camlType_fix
        ind_bodies0 ind_finite0
        ind_params0 ind_npars0
        ind_universes0 ind_variance0
        Hparam ind_bodies1 Hfo| =
    #|ind_bodies0|); eauto.
    induction ind_bodies0; cbn; eauto.
    intros. f_equal. destruct andb_and.
    destruct (a0 Hfo). eauto. 
  Qed.      

  
  Lemma CoqType_to_camlType_oneind_length mind Hparam x Hfo:
  List.length
      (CoqType_to_camlType_oneind
            mind x Hparam Hfo) =
  List.length (ind_ctors x).
  Proof.
    destruct x; cbn. destruct andb_and.
    destruct (a Hfo). clear.
    induction ind_ctors0; cbn; eauto.
    destruct andb_and. destruct (a0 i0).
    destruct a. cbn. f_equal. eapply IHind_ctors0.
  Qed. 

  Lemma CoqType_to_camlType'_nth mind Hparam x Hfo Hfo' ind:
  nth_error (ind_bodies mind) ind = Some x -> 
  ind < Datatypes.length (ind_bodies mind) -> 
    nth ind
         (CoqType_to_camlType'
            mind
            Hparam
            Hfo) [] =
    CoqType_to_camlType_oneind mind x Hparam Hfo'.
  Proof.
    destruct mind. revert ind. cbn in *. revert Hfo Hfo'.
    enough (
    forall ind_bodies1 (Hfo : is_true
           (forallb
              (firstorder_oneind
              (Build_mutual_inductive_body
              ind_finite0 ind_npars0
              ind_params0 ind_bodies1
              ind_universes0 ind_variance0)) ind_bodies0))
  (Hfo' : is_true
            (firstorder_oneind
            (Build_mutual_inductive_body
            ind_finite0 ind_npars0
            ind_params0 ind_bodies1
            ind_universes0 ind_variance0) x)) (ind : nat),
nth_error ind_bodies0 ind = Some x ->
ind < Datatypes.length ind_bodies0 ->
nth ind
  (CoqType_to_camlType_fix ind_bodies0 ind_finite0
     ind_params0 ind_npars0 ind_universes0
     ind_variance0 Hparam ind_bodies1 Hfo) [] =
CoqType_to_camlType_oneind
(Build_mutual_inductive_body
ind_finite0 ind_npars0
ind_params0 ind_bodies1
ind_universes0 ind_variance0) x Hparam Hfo'); eauto.
    induction ind_bodies0; intros. cbn in *; lia.
    destruct ind; cbn.
    - destruct andb_and. destruct (a0 Hfo).  
      cbn in H. inversion H. subst. f_equal. clear. apply bool_irr.
    - eapply IHind_bodies0; eauto.
      cbn in *; lia.
  Qed.

  Lemma CoqType_to_camlType'_nth_length mind Hparam Hfo ind x:
    nth_error (ind_bodies mind) ind = Some x -> 
    ind < Datatypes.length (ind_bodies mind) -> 
    List.length
        (nth ind
           (CoqType_to_camlType'
              mind
              Hparam
              Hfo) []) =
    List.length (ind_ctors x).
  Proof.
    intros; erewrite CoqType_to_camlType'_nth; eauto.
    eapply CoqType_to_camlType_oneind_length; eauto. 
    Unshelve. eapply forallb_nth_error in Hfo.
      erewrite H in Hfo. exact Hfo.         
  Qed. 

  Definition CoqType_to_camlType mind : 
    ind_params mind = [] -> 
    is_true (forallb (@firstorder_oneind Σb mind) (ind_bodies mind)) -> ADT :=
    fun Hparam H => (0, CoqType_to_camlType' mind Hparam H).
  
  Lemma CoqType_to_camlType_ind_ctors_nth 
    mind ind_ctors Hparam a k i :
    nth_error (CoqType_to_camlType_ind_ctors mind ind_ctors Hparam i) k
    = Some a ->
    exists a', nth_error ind_ctors k = Some a' /\
    exists i', 
    a = CoqType_to_camlType_ind_ctor 0 #|ind_bodies mind| (rev (cstr_args a' ++ ind_params mind)) i'.
  Proof. 
    revert a k i.
    induction ind_ctors; cbn; intros.
    - destruct k; inversion H.
    - destruct andb_and. destruct (a1 _).
      destruct k; destruct a.
      + inversion H. eexists; split; [reflexivity|].
        cbn. unfold firstorder_con in i. cbn in i.
        apply andb_and in i. destruct i as [i ?]. 
        exists i. repeat f_equal. apply bool_irr.
      + eapply IHind_ctors; eauto.
  Qed. 

  Lemma CoqType_to_camlType_ind_ctors_length 
  l n m i:
  List.length (CoqType_to_camlType_ind_ctor n m l i) = List.length l.
  revert n m i. induction l; cbn; eauto; intros. 
  destruct andb_and. destruct (a0 _). destruct a.
  cbn. now f_equal.
  Qed. 

  Lemma CoqType_to_camlType_ind_ctor_app
  l l' n m i : { i' & { i'' &  CoqType_to_camlType_ind_ctor n m (l++l') i = CoqType_to_camlType_ind_ctor n m l i' ++ CoqType_to_camlType_ind_ctor (#|l| + n) m l' i''}}.
  pose proof (ii := i). rewrite alli_app in ii. eapply andb_and in ii. destruct ii as [i' i''].
  exists i', i''. revert n i i' i''. induction l; cbn in *; intros.  
  - f_equal. eapply bool_irr.
  - destruct andb_and. destruct (a0 _). destruct a.      
    destruct andb_and. destruct (a _). rewrite <- app_comm_cons; repeat f_equal.
    * apply bool_irr.
    * assert (S (#|l| + n) = #|l| + S n) by lia. revert i''. rewrite H. apply IHl.
  Qed.      
    
  Lemma CoqType_to_camlType_oneind_nth mind Hparam x Hfo k l :
  nth_error (CoqType_to_camlType_oneind mind x Hparam Hfo) k = Some l
  -> exists l', nth_error (ind_ctors x) k = Some l' /\ #|l| = #|cstr_args l'|.
  Proof.
    destruct x; cbn. destruct andb_and.
    destruct (a Hfo). clear.
    revert k l. induction ind_ctors0; cbn; eauto.
    - intros k l H. rewrite nth_error_nil in H. inversion H.
    - destruct andb_and. destruct (a0 i0).
      destruct a. intros k l H. destruct k; cbn. 
      + eexists; split; [reflexivity |]. cbn in *.
        inversion H. rewrite CoqType_to_camlType_ind_ctors_length.
        rewrite Hparam. rewrite app_nil_r. apply rev_length.
      + cbn in *. now eapply IHind_ctors0. 
  Qed. 

  Lemma CoqType_to_camlType_oneind_nth' mind Hparam x Hfo k l :
  nth_error (ind_ctors x) k = Some l 
  -> exists l', nth_error (CoqType_to_camlType_oneind mind x Hparam Hfo) k = Some l' /\ #|l'| = #|cstr_args l|.
  Proof.
    destruct x; cbn. destruct andb_and.
    destruct (a Hfo). clear.
    revert k l. induction ind_ctors0; cbn; eauto.
    - intros k l H. rewrite nth_error_nil in H. inversion H.
    - destruct andb_and. destruct (a0 i0).
      destruct a. intros k l H. destruct k; cbn. 
      + eexists; split; [reflexivity |]. cbn in *.
        inversion H. rewrite CoqType_to_camlType_ind_ctors_length.
        rewrite Hparam. rewrite app_nil_r. apply rev_length.
      + cbn in *. now eapply IHind_ctors0. 
  Qed. 


  #[local] Instance cf_ : checker_flags := extraction_checker_flags.
  #[local] Instance nf_ : PCUICSN.normalizing_flags := PCUICSN.extraction_normalizing.

  Parameter Normalisation : forall Σ0 : PCUICAst.PCUICEnvironment.global_env_ext, PCUICTyping.wf_ext Σ0 -> PCUICSN.NormalizationIn Σ0.

  Parameter compile_pipeline : global_env -> term -> t.
  
  Parameter compile_pipeline_tConstruct_nil : forall Σ i n inst,
    compile_pipeline Σ (tConstruct i n inst) =
    match lookup_constructor_args Σ i with
    | Some num_args =>
      Mnum (numconst_Int (int_of_nat (nonblocks_until n num_args)))
    | None => Mstring "error: inductive not found"
    end.

  Parameter compile_pipeline_tConstruct_cons : forall Σ i n inst l, 
    #|l| > 0 ->
    compile_pipeline Σ (mkApps (tConstruct i n inst) l) =
    match lookup_constructor_args Σ i with
    | Some num_args =>
      Mblock
        (int_of_nat (blocks_until n num_args),
         map_InP l (fun (x : term) (_ : In x l) => compile_pipeline Σ x))
    | None => Mstring "error: inductive not found"
    end.

  Parameter compile_app : forall `{Heap} `{WcbvFlags} 
  (cf:=config.extraction_checker_flags) 
  (Σ:global_env_ext_map) t u na A B,
  ∥ Σ ;;; [] |- t : tProd na A B ∥ ->
  ~ ∥Extract.isErasable Σ [] t∥ -> 
  compile_pipeline Σ (tApp t u) = 
  Mapply (compile_pipeline Σ t, [compile_pipeline Σ u]).

  Parameter compile_function : forall `{Heap} `{WcbvFlags} 
  (cf:=config.extraction_checker_flags)
  (Σ:global_env_ext_map) h h' f v na A B,
  ∥ Σ ;;; [] |- f : tProd na A B ∥ ->
  ~ ∥Extract.isErasable Σ [] f∥ ->
  eval [] empty_locals h (compile_pipeline Σ f) h' v ->
  isFunction v = true.    

  Parameter compile_pure : forall `{Heap} `{WcbvFlags} Σ t, is_true (isPure (compile_pipeline Σ t)).

  Lemma filter_length_nil ind k mind Eind Hparam Hfo :
    nth_error (ind_bodies mind) ind = Some Eind ->
  List.length
  (filter (fun x0 : nat =>  match x0 with
      | 0 => true
      | S _ => false
      end)
     (firstn k (map cstr_nargs (ind_ctors Eind)))) = 
  List.length
           (filter (fun x : list camlType =>
               match x with
               | [] => true
               | _ :: _ => false
               end)
              (firstn k
                 (nth ind
                    (CoqType_to_camlType' mind
                       Hparam Hfo) []))).
   Proof. 
    intro Hind. unshelve erewrite CoqType_to_camlType'_nth; eauto.
    - eapply nth_error_forallb in Hfo; eauto.
    - destruct Eind; cbn. destruct andb_and. destruct (a _).
      rewrite (filter_ext _ (fun x =>
      match #|x| with
      | 0 => true
      | S _ => false
      end)).
      { clear. intro l; induction l; eauto. }
      revert k i0. clear Hind i i1 a. induction ind_ctors0; cbn; intros. 
      + intros. now repeat rewrite firstn_nil.
      + destruct k; eauto; cbn. destruct andb_and. destruct (a0 _). cbn.
        destruct a. cbn. rewrite CoqType_to_camlType_ind_ctors_length.
        revert i1. cbn. rewrite Hparam app_nil_r. cbn.
        rewrite rev_length. intro.  
        destruct cstr_args0; cbn. 
        * intros; f_equal. eapply IHind_ctors0; eauto.
        * eapply IHind_ctors0.
    - now eapply nth_error_Some_length. 
  Qed.                       

    Lemma filter_length_not_nil ind k mind Eind Hparam Hfo :
    nth_error (ind_bodies mind) ind = Some Eind ->
  List.length
  (filter (fun x0 : nat =>  match x0 with
      | 0 => false
      | S _ => true 
      end)
     (firstn k (map cstr_nargs (ind_ctors Eind)))) = 
  List.length
           (filter (fun x : list camlType =>
               match x with
               | [] => false
               | _ :: _ => true
               end)
              (firstn k
                 (nth ind
                    (CoqType_to_camlType' mind
                       Hparam Hfo) []))).
  Proof. 
    intro Hind. unshelve erewrite CoqType_to_camlType'_nth; eauto.
    - eapply nth_error_forallb in Hfo; eauto.
    - destruct Eind; cbn. destruct andb_and. destruct (a _).
      rewrite (filter_ext _ (fun x =>
      match #|x| with
      | 0 => false
      | S _ => true
      end)).
      { clear. intro l; induction l; eauto. }
      revert k i0. clear Hind i i1 a. induction ind_ctors0; cbn; intros. 
      + intros. now repeat rewrite firstn_nil.
      + destruct k; eauto; cbn. destruct andb_and. destruct (a0 _). cbn.
        destruct a. cbn. rewrite CoqType_to_camlType_ind_ctors_length.
        revert i1. cbn. rewrite Hparam app_nil_r. cbn.
        rewrite rev_length. intro.  
        destruct cstr_args0; cbn. 
        * eapply IHind_ctors0.
        * intros; f_equal. eapply IHind_ctors0; eauto.
    - now eapply nth_error_Some_length. 
  Qed. 
End firstorder.

Lemma CoqType_to_camlType_oneind_type_Rel n k decl_type Hfo :
let T := CoqType_to_camlType_oneind_type (Σb := []) n k decl_type Hfo in
exists i,  (k <= i) /\ (i < n + k) /\ T = Rel (n - S (i-k)).
Proof.
unfold CoqType_to_camlType_oneind_type.
unfold firstorder_type in Hfo.
set (fst (PCUICAstUtils.decompose_app decl_type)) in *.
set (snd (PCUICAstUtils.decompose_app decl_type)) in *.
destruct t; destruct l; inversion Hfo; cbn; eauto.
- apply andb_and in H0. destruct H0. apply leb_complete in H, H0.
  exists n0; repeat split; eauto.
- destruct ind; inversion Hfo.
- destruct ind; inversion Hfo.
Qed.   

Lemma CoqType_to_camlType_oneind_Rel mind ind Hparam Hfo larg T k : 
In larg (CoqType_to_camlType_oneind (Σb := []) mind ind Hparam Hfo) ->
nth_error larg k = Some T -> exists i, (k <= i) /\ (i < #|ind_bodies mind| + k) /\ T = Rel (#|ind_bodies mind| - S (i-k)).
Proof. 
destruct mind, ind. revert k Hfo. induction ind_ctors0; intros k Hfo Hlarg HT.
- cbn in *; destruct andb_and. destruct (a Hfo). destruct (in_nil Hlarg).
- cbn; cbn in Hlarg. destruct andb_and. cbn in Hfo. destruct (a0 Hfo). 
  destruct andb_and. destruct (a1 i0). destruct a.
  unfold In in Hlarg. destruct Hlarg.
  2: { eapply IHind_ctors0; eauto. cbn. destruct andb_and.
        destruct (a _). rewrite (bool_irr _ i6 i4). eauto.
        Unshelve.
        cbn. apply andb_and. split; cbn; eauto. }
  cbn in Hparam, i3. rewrite Hparam in i3, H. rewrite app_nil_r in i3, H.
  clear - i3 HT H. set (rev cstr_args0) in *. rewrite <- H in HT.
  pose proof (nth_error_Some_length HT).
  revert T HT. clear H H0. cbn; set (#|ind_bodies0|) in *. 
  setoid_rewrite <- (Nat.sub_0_r k) at 1. assert (k >= 0) by lia. revert H.  
  revert k i3. generalize 0 at 1 2 3 4.
  induction l; cbn; intros. 1: { rewrite nth_error_nil in HT. inversion HT. }
  destruct andb_and. destruct (a0 i3). destruct a.
  cbn in HT. 
  case_eq (k - n0).
  + intro Heq.
    rewrite Heq in HT. inversion HT. 
    unshelve epose (CoqType_to_camlType_oneind_type_Rel _ _ _ _).
    5: erewrite H1 in e. rewrite H1. destruct e as [i2 [? [? ?]]]. exists (i2 + k - n0).
    repeat split. all: try lia. rewrite H3; f_equal. lia. 
  + intros ? Heq. rewrite Heq in HT. cbn in HT. eapply IHl.
    2: { assert (n1 = k - S n0) by lia. now rewrite H0 in HT. }
    lia.  
Qed.  

Lemma CoqType_to_camlType'_unfold mind Hparam Hfo l : 
In l (CoqType_to_camlType' (Σb := []) mind Hparam Hfo) ->
exists ind Hfo', l =  CoqType_to_camlType_oneind (Σb := []) mind ind Hparam Hfo'.
Proof.
  destruct mind; cbn in *. revert Hfo.
  enough (forall ind_bodies1, forall
  Hfo : is_true
          (forallb
             (firstorder_oneind
                {|
                  Erasure.P.PCUICEnvironment.ind_finite := ind_finite0;
                  Erasure.P.PCUICEnvironment.ind_npars := ind_npars0;
                  Erasure.P.PCUICEnvironment.ind_params := ind_params0;
                  Erasure.P.PCUICEnvironment.ind_bodies := ind_bodies1;
                  Erasure.P.PCUICEnvironment.ind_universes := ind_universes0;
                  Erasure.P.PCUICEnvironment.ind_variance := ind_variance0
                |}) ind_bodies0),
In l
  (CoqType_to_camlType_fix (Σb := []) ind_bodies0 ind_finite0 ind_params0 ind_npars0 ind_universes0 ind_variance0
     Hparam ind_bodies1 Hfo) ->
exists
  (ind : one_inductive_body) (Hfo' : is_true
                                       (firstorder_oneind
                                          {|
                                            Erasure.P.PCUICEnvironment.ind_finite := ind_finite0;
                                            Erasure.P.PCUICEnvironment.ind_npars := ind_npars0;
                                            Erasure.P.PCUICEnvironment.ind_params := ind_params0;
                                            Erasure.P.PCUICEnvironment.ind_bodies := ind_bodies1;
                                            Erasure.P.PCUICEnvironment.ind_universes := ind_universes0;
                                            Erasure.P.PCUICEnvironment.ind_variance := ind_variance0
                                          |} ind)),
  l =
  CoqType_to_camlType_oneind (Σb := [])
    {|
      Erasure.P.PCUICEnvironment.ind_finite := ind_finite0;
      Erasure.P.PCUICEnvironment.ind_npars := ind_npars0;
      Erasure.P.PCUICEnvironment.ind_params := ind_params0;
      Erasure.P.PCUICEnvironment.ind_bodies := ind_bodies1;
      Erasure.P.PCUICEnvironment.ind_universes := ind_universes0;
      Erasure.P.PCUICEnvironment.ind_variance := ind_variance0
    |} ind Hparam Hfo').
  { eapply H; eauto. }
  induction ind_bodies0; cbn; intros.
  - inversion H.
  - destruct andb_and. destruct (a0 Hfo). destruct H.
    + exists a. now exists i0.
    + eapply IHind_bodies0; eauto.
  Qed.  
    
Lemma CoqType_to_camlType'_Rel mind ind Hparam Hfo larg T k : 
let typ := (CoqType_to_camlType' (Σb := []) mind Hparam Hfo) in
In larg (nth ind typ []) -> 
nth_error larg k = Some T -> exists i, (k <= i) /\ (i < #|ind_bodies mind| + k) /\ T = Rel (#|ind_bodies mind| - S (i-k)).
Proof.
  intro typ. destruct (nth_in_or_default ind typ []).
  2: { rewrite e. intros Hlarg; destruct (in_nil Hlarg). }
  intro Hlarg. unfold typ in *. eapply CoqType_to_camlType'_unfold in i.
  destruct i as [ind' [Hfo' i]]. rewrite i in Hlarg. now eapply CoqType_to_camlType_oneind_Rel.
Qed.

Lemma CoqType_to_camlType'_Rel' mind ind Hparam Hfo larg T k : 
let typ := (CoqType_to_camlType' (Σb := []) mind Hparam Hfo) in
In larg (nth ind typ []) -> 
nth_error larg k = Some T -> exists i, (0 <= i) /\ (i < #| ind_bodies mind|) /\ T = Rel (#|ind_bodies mind| - S i).
Proof.
  intros. unshelve epose (CoqType_to_camlType'_Rel _ ind); eauto. 
  edestruct e as [i [? [? ?]]]; eauto. exists (i - k). repeat split; eauto.
  all: lia.
Qed.

  Inductive nonDepProd : term -> Type :=
    | nonDepProd_tInd : forall i u, nonDepProd (tInd i u)
    | nonDepProd_Prod : forall na A B, closed A -> nonDepProd B -> nonDepProd (tProd na A B).

  Lemma nonDep_closed t : nonDepProd t -> closed t.  
  Proof.
    induction 1; cbn; eauto. 
    rewrite i; cbn. eapply PCUICLiftSubst.closed_upwards; eauto.
  Qed. 

  Fixpoint nonDep_decompose (t:term) (HnonDep : nonDepProd t) : list term * term
    := match HnonDep with 
    | nonDepProd_tInd i u => ([], tInd i u)
    | nonDepProd_Prod na A B clA ndB => let IH := nonDep_decompose B ndB in (A :: fst IH, snd IH)
    end.

  Lemma nonDep_typing_spine (cf:=config.extraction_checker_flags) (Σ:global_env_ext) us u_ty s (nonDep : nonDepProd u_ty) :
    PCUICTyping.wf Σ ->
    Σ ;;; [] |- u_ty : tSort s -> 
    All2 (fun u uty => Σ ;;; [] |- u : uty) us (fst (nonDep_decompose u_ty nonDep))  ->
    PCUICGeneration.typing_spine Σ [] u_ty us (snd (nonDep_decompose u_ty nonDep)).
  Proof.
  revert s us. induction nonDep; cbn in *; intros s us wfΣ Hty; cbn.
  - intro H; depelim H. econstructor; [|reflexivity]. eexists; eauto.
  - set (PCUICInversion.inversion_Prod Σ wfΣ Hty) in *.
    destruct s0 as [s1 [s2 [HA [HB ?]]]]; cbn. intro H; depelim H.   
    epose (strengthening_type [] ([],, vass na A) [] B s2).
    pose proof (nonDep_closed _ nonDep).
    edestruct s0 as [s' [Hs _]]. cbn.  rewrite PCUICLiftSubst.lift_closed; eauto.
    econstructor; try reflexivity; eauto.
    + eexists; eauto.
    + rewrite /subst1 PCUICClosed.subst_closedn; eauto.
  Qed.      

  Lemma firstorder_con_notApp `{checker_flags} mind a :
    firstorder_con (Σb := []) mind a -> 
    All (fun decl => ~ (isApp (decl_type decl))) (cstr_args a).
  Proof.
    intros Hfo. destruct a; cbn in *. induction cstr_args0; eauto.
    cbn in Hfo. rewrite rev_app_distr in Hfo. cbn in Hfo.
    rewrite alli_app in Hfo. rewrite <- plus_n_O in Hfo. apply andb_and in Hfo. destruct Hfo as [? Hfo].
    econstructor.
    - clear H0 IHcstr_args0. destruct a.
      simpl in *. apply andb_and in Hfo. destruct Hfo as [Hfo _].
      unfold firstorder_type in Hfo. cbn in Hfo. 
      assert (snd (PCUICAstUtils.decompose_app decl_type) = []).
      { destruct snd; eauto. destruct fst; try destruct ind; inversion Hfo. } 
      destruct decl_type; try solve [inversion Hfo]; eauto. intros _.
      cbn in H0. pose proof (PCUICInduction.decompose_app_rec_length decl_type1 [decl_type2]).
      rewrite H0 in H1. cbn in H1. lia. 
    - apply IHcstr_args0. now rewrite rev_app_distr.
  Qed. 

  Lemma firstorder_type_closed kn l k T :
    ~ (isApp T) -> 
    firstorder_type (Σb := []) #|ind_bodies l| k T -> 
    closed (subst (inds kn [] (ind_bodies l)) k T@[[]]).
  Proof. 
    intro nApp; destruct T; try solve [inversion 1]; cbn in *; eauto.  
    - intro H; apply andb_and in H. destruct H. rewrite H.
      eapply leb_complete in H, H0. rewrite nth_error_inds; [lia|eauto].
    - now destruct nApp.
  Qed. 

  Lemma firstorder_nonDepProd mind kn Eind cstr_args0 x lind ind :
  nth_error (ind_bodies mind) ind = Some Eind ->
  is_assumption_context cstr_args0 ->
  All (fun decl => ~ (isApp (decl_type decl))) cstr_args0 ->
  let Ts := CoqType_to_camlType_ind_ctor (Σb := []) 0 #|ind_bodies mind| (rev cstr_args0) x in 
  All2 (fun a b => 0 <= a /\ a < #|ind_bodies mind| /\ b = Rel (#|ind_bodies mind| - S a)) lind Ts -> 
  { nd : nonDepProd (subst0 (inds kn [] (ind_bodies mind))
                     (it_mkProd_or_LetIn cstr_args0 (tRel (#|ind_bodies mind| - S ind + #|cstr_args0|)))@[[]]) &
  (fst (nonDep_decompose _ nd) = map (fun b : nat => tInd {| inductive_mind := kn; inductive_ind := #|ind_bodies mind| - S b |} []) lind) /\
  (snd (nonDep_decompose _ nd) = tInd {| inductive_mind := kn; inductive_ind := ind |} []) }.
Proof.
    intros Hind Hlets Happ. 
    set (X := (tRel (#|ind_bodies mind| - S ind + #|cstr_args0|))).
    assert (Hmind: #|ind_bodies mind| > 0).
    { destruct (ind_bodies mind); [|cbn; lia]. rewrite nth_error_nil in Hind. inversion Hind. }
    assert (HX : {nd : nonDepProd (subst (inds kn [] (ind_bodies mind)) #|cstr_args0| X@[[]]) &
      (fst (nonDep_decompose _ nd) = map (fun b : nat => tInd {| inductive_mind := kn; inductive_ind := #|ind_bodies mind| - S b |} []) []) /\ 
      (snd (nonDep_decompose _ nd) = tInd {| inductive_mind := kn; inductive_ind := ind |} [])}).
    { cbn.
      assert (#|cstr_args0| <= #|ind_bodies mind| - S ind + #|cstr_args0|) by lia.
      apply leb_correct in H. 
      destruct (_ <=? _); [| lia]. 
      assert (Heq : #|ind_bodies mind| - S ind + #|cstr_args0| - #|cstr_args0| < #|ind_bodies mind|) by lia. 
      pose proof (@nth_error_inds kn [] _ _ Heq). revert H0. 
      destruct (nth_error (inds _ _ _) _); [| inversion 1].
      inversion 1. clear H0 H2. unshelve eexists. econstructor. cbn. split; [sq; eauto|].
      repeat f_equal. destruct (ind_bodies _); [inversion Hmind|]. apply nth_error_Some_length in Hind. cbn in *. lia.  
    }
    clearbody X. intros Ts Hrel. rewrite <- (app_nil_r lind). revert HX Ts Hrel. generalize (@nil nat) as lind_done.
    revert X lind x. 
    induction cstr_args0; intros X lind x lind_done HX Ts Hrel; simpl in *; eauto.
    1: { eapply All2_length in Hrel. eapply length_nil in Hrel. 
         now subst. }
    unfold Ts in Hrel. edestruct (CoqType_to_camlType_ind_ctor_app (Σb := [])) as [? [? ->]] in Hrel.
    apply All2_app_inv_r in Hrel as [lind' [lind'' [? [Hrel Ha]]]]. subst.
    rewrite <- app_assoc. eapply IHcstr_args0; eauto.
    { destruct decl_body;[inversion Hlets| eauto]. }
    { inversion Happ; eauto. }
    destruct a. destruct decl_body.
    + inversion Hlets.
    + destruct HX as [ndX [Xfst Xsnd]]. cbn. 
      unshelve econstructor. econstructor; eauto.
      { cbn in *. clear -x1 Happ. 
        apply andb_and in x1; destruct x1 as [x1 _].
        rewrite <- plus_n_O in x1. rewrite rev_length in x1. apply firstorder_type_closed; eauto.
        inversion Happ; eauto.
      }
      split; eauto.
      rewrite map_app. cbn. set (subst _ _ _). set (fst _). change (t :: y) with ([t]++y). f_equal; eauto. 
      unfold t. cbn in Ha. destruct andb_and. destruct (a _). clear a i i1.
      destruct decl_type; inversion i0.
      * cbn. revert i0 Ha. rewrite rev_length. cbn.  intros. apply andb_and in i0. destruct i0. rewrite <- plus_n_O in H.
        inversion Ha. subst. apply All2_length in X0. apply length_nil in X0. subst. clear Ha. 
        rewrite H. rewrite nth_error_inds. { apply leb_complete in H1. lia. } 
        cbn. repeat f_equal; eauto. destruct H4 as [? [? ?]]. inversion H4. 
        apply leb_complete in H1. lia.   
      * cbn in *. inversion Happ; subst. now cbn in H1. 
      * cbn in H0. destruct ind0. inversion H0.
  Qed. 

  Record pcuic_good_for_extraction {Σ : global_env} := 
    { ctors_max_length : forall mind j k ind ctors, nth_error mind j = Some ind -> nth_error (ind_ctors ind) k = Some ctors -> 
        #|cstr_args ctors| < int_to_nat max_length;
      ind_ctors_wB : forall mind j ind, nth_error mind j = Some ind -> #|ind_ctors ind| <= Z.to_nat Uint63.wB }.
  Arguments pcuic_good_for_extraction : clear implicits.

  Lemma is_assumption_context_length c : is_assumption_context c -> #|c| = context_assumptions c.
  Proof.
    induction c; eauto; cbn. destruct decl_body; cbn. 
    - inversion 1.
    - intros; f_equal; eauto.
  Qed.  
  
  Lemma nth_error_firstn A n m (l:list A) x : nth_error (firstn n l) m = Some x -> nth_error l m = Some x.
  Proof.
    revert n l. induction m; intros n l H; destruct n, l; cbn in *; try solve [inversion H]; eauto.
  Qed. 

  Lemma camlValue_to_CoqValue `{Heap} `{WcbvFlags} (cf:=config.extraction_checker_flags)
    univ retro univ_decl kn mind
    (Hparam : ind_params mind = [])
    (Hindices : Forall (fun ind => ind_indices ind = []) (ind_bodies mind))
    (Hnparam : ind_npars mind = 0)
    (Hmono : ind_universes mind = Monomorphic_ctx)
    (empty_heap : heap)
    (Hfo : is_true (forallb (@firstorder_oneind [] mind) (ind_bodies mind))) :
    let adt := CoqType_to_camlType mind Hparam Hfo in
    let Σ : global_env_ext_map := (build_global_env_map (mk_global_env univ [(kn , InductiveDecl mind)] retro), univ_decl) in
    pcuic_good_for_extraction Σ ->
    PCUICTyping.wf Σ ->
    with_constructor_as_block = true ->
    forall v ind Eind, 
    ind < List.length (snd adt) ->
    lookup_inductive Σ (mkInd kn ind) = Some (mind, Eind) ->
    realize_ADT _ _ [] [] adt [] All_nil ind v ->
    exists t, 
    PCUICEtaExpand.expanded Σ [] t /\
    ∥ Σ ;;; [] |- t : tInd (mkInd kn ind) [] ∥ /\ 
    forall h, eval [] empty_locals h (compile_pipeline Σ t) h v.
  Proof. 
    rename H into HP; rename H0 into HHeap; rename H1 into H. 
    intros adt Σ good wfΣ Hflag v ind Eind Hind Hlookup [step Hrel].
    revert kn mind Hparam Hindices Hnparam Hmono Hfo v ind Eind adt Σ good wfΣ Hflag Hind Hlookup Hrel. 
    induction step; intros; [inversion Hrel|].
    apply leb_correct in Hind. simpl in Hrel, Hind. 
    unfold Nat.ltb in Hrel. rewrite Hind in Hrel.
    destruct Hrel as [Hrel | Hrel].
    - apply Existsi_spec in Hrel as [k [Ts [Hk [HkS [Hrel HTs]]]]].
      cbn in HkS.
      destruct (filter_firstn' _ _ _ _ HkS) as [k' [Hk' [Hfilter Hwit]]].
      destruct Hwit as [As [Ha [Ha' Ha'']]].
      pose (MCList.nth_error_spec (ind_bodies mind) ind).
      destruct n; cbn; intros.
        2: { apply leb_complete in Hind.
             rewrite CoqType_to_camlType'_length in Hind. lia. } 
      pose (MCList.nth_error_spec (ind_ctors x) k').
      assert (Hfo_x : is_true (@firstorder_oneind [] mind x)).
        { clear -e Hfo; eapply forallb_nth_error in Hfo; erewrite e in Hfo; exact Hfo. }
      destruct n; intros; eauto.
        2: { 
          unshelve erewrite CoqType_to_camlType'_nth in Hk'; eauto.
          rewrite CoqType_to_camlType_oneind_length in Hk'.
          lia. }
      assert (Hcstr: forall b n, nth_error (ind_ctors x) n = Some b -> #|cstr_args b| = context_assumptions (cstr_args b)). 
        { intros b m Hx; assert (declared_constructor Σ ({| inductive_mind := kn; inductive_ind := ind |}, m) mind x b).
          { split; eauto. split; eauto. simpl. now left. }
            apply is_assumption_context_length.
            eapply PCUICWeakeningEnvTyp.on_declared_constructor in H0
            as [? [? ?]].
            eapply All2_In in onConstructors as [[univs onConstructor]].
            2: { now eapply nth_error_In. }
            now eapply on_lets_in_type in onConstructor.
         } 
    
      exists (tConstruct (mkInd kn ind) k' []); cbn; split; [|split].
      + eapply PCUICEtaExpand.expanded_tConstruct_app with (mind := mind) (idecl := x) (cdecl := x0) (args:=[]).
        3: eauto. { unfold declared_constructor, declared_inductive. now cbn. }
           unshelve erewrite CoqType_to_camlType'_nth in Ha; eauto.
           eapply CoqType_to_camlType_oneind_nth in Ha as [? [? ?]].
           rewrite Hnparam. erewrite <- Hcstr; eauto. cbn. rewrite e0 in H0.
           inversion H0. destruct As; inversion Ha''; subst; cbn in *; lia. 
      + unshelve epose proof (Htyp := type_Construct Σ [] (mkInd kn ind) k' [] mind x x0 _ _ _).
          ** econstructor.
          ** unfold declared_constructor, declared_inductive. now cbn.
          ** unfold consistent_instance_ext, consistent_instance; cbn.
             now rewrite Hmono.
          ** 
          unshelve erewrite CoqType_to_camlType'_nth in Hfilter, Ha, Ha'; eauto.
          unfold CoqType_to_camlType_oneind in Hfilter, Ha, Ha'. destruct x. cbn in *. 
          destruct andb_and. destruct (a _).
          apply CoqType_to_camlType_ind_ctors_nth in Ha.
          destruct Ha as [a0 [? [? ?]]].
          rewrite H1 in Ha''.
          unfold type_of_constructor in Htyp.  
          assert (CoqType_to_camlType_ind_ctor 0 #|ind_bodies mind|
          (rev (cstr_args a0 ++ ind_params mind)) x = []).
          { destruct CoqType_to_camlType_ind_ctor; eauto. }
          clear Ha''. apply f_equal with (f := @List.length _) in H2.
          rewrite CoqType_to_camlType_ind_ctors_length in H2.
          cbn in H2. erewrite rev_length, app_length in H2.
          assert (Ha0 : #|cstr_args a0| = 0) by lia. apply length_nil in Ha0.
          rewrite e0 in H0. inversion H0. subst; clear H0.
          unfold PCUICTyping.wf in wfΣ. inversion wfΣ as [_ wfΣ'].
          cbn in wfΣ'. inversion wfΣ'; subst. clear X.
          inversion X0 as [_ ? _ wf_ind]; cbn in *.
          destruct wf_ind as [wf_ind _ _ _].
          inversion wfΣ'; subst. inversion X1; subst. inversion on_global_decl_d. 
          eapply Alli_nth_error in onInductives; eauto. cbn in onInductives.
          inversion onInductives. unfold PCUICGlobalMaps.on_constructors in *. cbn in *.
          eapply All2_nth_error_Some  in onConstructors; eauto. destruct onConstructors as [l' [? onConstructor]].
          erewrite @cstr_eq with (i:=ind) in Htyp; eauto.
          unfold cstr_concl in Htyp. 
          erewrite Hparam, Ha0 in Htyp. cbn in Htyp. 
          assert (cstr_indices a0 = []).
          { apply length_nil. erewrite @cstr_indices_length with (Σ:=Σ) (ind:=(mkInd kn ind,k')); eauto. 
            2: { repeat split. cbn. left. reflexivity. all:cbn; eauto. } cbn. eapply nth_error_forall in Hindices; eauto.
                 cbn in Hindices. now rewrite Hindices. }
          rewrite H0 in Htyp; clear H0; cbn in Htyp.
          rewrite Ha0 Hparam in Htyp. cbn in Htyp.   
          rewrite inds_spec in Htyp.  
          assert (#|ind_bodies mind| - S ind + 0 + 0 - 0 = #|ind_bodies mind| - S ind)
          by lia. rewrite H0 in Htyp; clear H0.
          erewrite <- mapi_length in Htyp. 
          rewrite <- nth_error_rev, nth_error_mapi, e in Htyp.
          cbn in Htyp. sq; exact Htyp.  
          now rewrite mapi_length.
     + rewrite (compile_pipeline_tConstruct_nil Σ). simpl. 
        unfold lookup_constructor_args. rewrite Hlookup.
        rewrite Hrel. clear Hrel v.
        pose (MCList.nth_error_spec (ind_bodies mind) ind).
        apply leb_complete in Hind. rewrite CoqType_to_camlType'_length in Hind.    
        destruct n; [|lia]. inversion e. rewrite <- H1 in Hfo_x.   
        unshelve erewrite CoqType_to_camlType'_nth in Hfilter; eauto.
        unfold lookup_inductive, lookup_inductive_gen, lookup_minductive_gen in Hlookup. cbn in Hlookup.
        rewrite ReflectEq.eqb_refl in Hlookup.
        unfold nonblocks_until. 
        unshelve erewrite filter_length_nil with (mind:=mind) (ind:=ind); eauto.
        2: { destruct (nth_error (ind_bodies mind) ind); now inversion Hlookup. }
        rewrite Hfilter. 
        unshelve erewrite CoqType_to_camlType'_nth; eauto.
        unfold int_of_nat. set (Z.of_nat _).
        assert (z = (z mod Uint63.wB)%Z).
        symmetry; eapply Z.mod_small.
        split. lia.
        unfold z; clear z. set (List.length _).
        enough (n < S (Z.to_nat (Z.pred Uint63.wB))). 
        clearbody n. 
        eapply Z.lt_le_trans. 
        eapply inj_lt. eapply H0. clear.
        rewrite Nat2Z.inj_succ. 
        rewrite Z2Nat.id. now vm_compute. now vm_compute.
        unfold n. rewrite <- Nat.le_succ_l.
        apply le_n_S. etransitivity. apply filter_length.
        rewrite firstn_length.
        unshelve erewrite CoqType_to_camlType'_nth_length in Hk'; eauto.
        etransitivity. apply Nat.le_min_l.
        apply good.(ind_ctors_wB) in e1. lia.
        unshelve erewrite CoqType_to_camlType'_nth in Hk'; eauto.
        intro h. rewrite -> H0 at 2. rewrite <- Int63.of_Z_spec. 
        econstructor.
    - apply leb_complete in Hind. 
      apply Existsi_spec in Hrel as [k [Ts [Hk [HkS [Hrel HTs]]]]].
      cbn in HkS.
      destruct (filter_firstn' _ _ _ _ HkS) as [k' [Hk' [Hfilter Hwit]]].
      destruct Hrel as [v' [eq Hv']].
      destruct Ts as [|T Ts]. (* not possible filtered *) 
      + apply filter_nth_error in HTs. destruct HTs as [_ HTs]. 
        inversion HTs.
      + pose proof (HTs' := HTs). apply filter_nth_error in HTs. destruct HTs as [HTs _].
        subst.
        assert (Forall2 (fun v T => 
        (exists t, PCUICEtaExpand.expanded Σ [] (fst t) /\ ∥ (Σ , univ_decl) ;;; [] |- fst t : tInd (mkInd kn (#|ind_bodies mind| - S (snd t))) [] ∥ /\ 
        (forall h, eval [] empty_locals h (compile_pipeline Σ (fst t)) h v)
        /\ (0 <= snd t) /\ (snd t < #|ind_bodies mind|) /\ T = Rel (#|ind_bodies mind| - S (snd t)))) v' (T::Ts)).
        { 
          assert (Forall (fun T => exists l l', In (l ++ [T] ++ l') (nth ind (CoqType_to_camlType' mind Hparam Hfo) [])) (T::Ts)).
          { clear -HTs. set (l := T::Ts) in *. clearbody l.
            assert (exists l', In (l' ++ l) (nth ind (CoqType_to_camlType' mind Hparam Hfo) [])).  
            { exists []; eauto.  }
            clear T Ts HTs; revert H. induction l; econstructor.
            - destruct H as [l' HIn]. exists l'; exists l; eauto.
            - eapply IHl. destruct H as [l' HIn]. exists (l' ++ [a]). 
              now rewrite <- app_assoc. } 
          eapply Forall2_Forall_mix; [| apply H0]; clear H0 Hwit HkS Hk HTs HTs'. 
          unfold realize_value, to_realize_value in Hv'.
          induction Hv'; econstructor. 
          - clear IHHv'. intros [l0 [l0' HTs]].
            unshelve eapply CoqType_to_camlType'_Rel with (k:=#|l0|) in HTs; try reflexivity.
            3: { rewrite nth_error_app2; eauto. rewrite Nat.sub_diag. reflexivity. }
            destruct HTs as [i [? [? Hx ]]]; subst. 
            cbn in H0. unfold realize_term in H0.
            specialize (H0 empty_heap).
            destruct H0 as [t [h' [Hheap ?]]].
            specialize (H0 empty_heap h' _ Hheap). rewrite to_list_nth in H0.
            + rewrite CoqType_to_camlType'_length. lia.
            + pose (MCList.nth_error_spec (ind_bodies mind) (i - #|l0|)).
              destruct n. 2: { clear -H1 H2 l1. lia. }
              eapply IHstep in H0; eauto.
              2: { unfold CoqType_to_camlType; cbn. now rewrite CoqType_to_camlType'_length. }
              destruct H0 as [t' H0]. cbn. 
              exists (t',i - #|l0|). cbn. intros. destruct H0 as [? [? ?]]. 
              sq. repeat split; eauto. lia. 
              unfold lookup_inductive, lookup_inductive_gen, lookup_minductive_gen, lookup_env. cbn.
              rewrite ReflectEq.eqb_refl. erewrite nth_error_nth'; cbn; [eauto|lia].
              Unshelve. eauto.  
          - eapply IHHv'. 
        }
        pose proof (Hv'Ts := Forall2_length H0).
        destruct (All_exists _ _ _ _ _ _ H0) as [lv' Hlv']. clear H0. 
        eapply Forall2_sym in Hlv'. cbn in Hlv'.
        (* pose proof (Forall2_forall _ _ Hlv'). clear Hlv'. rename H0 into Hlv'.  *)
        eexists (mkApps (tConstruct (mkInd kn ind) k' []) (map fst lv')).
        eapply Forall_Forall2_and_inv in Hlv'.
        destruct Hlv' as [Hlv' Hexpand'].
        eapply Forall_Forall2_and_inv in Hlv'.
        destruct Hlv' as [Hlv' Hvallv'].
        eapply Forall2_and_inv in Hlv'. destruct Hlv' as [Heval Hlv'].
        split; [|split].
        3: { pose proof (Forall2_forall _ _ Heval). clear Heval. rename H0 into Heval. 
            intro h; specialize (Heval h). clear Hlv'. rewrite (compile_pipeline_tConstruct_cons Σ). 
            rewrite map_length. erewrite Forall2_length; eauto.
            pose proof (Forall2_length Hv').
            rewrite zip_length; try rewrite <- H0; cbn; lia.
            unfold lookup_constructor_args. rewrite Hlookup.
            unfold lookup_inductive, lookup_inductive_gen, lookup_minductive_gen in Hlookup.
            cbn in Hlookup. rewrite ReflectEq.eqb_refl in Hlookup.
            assert (HEind : nth_error (ind_bodies mind) ind = Some Eind).
            { destruct (nth_error (ind_bodies mind) ind); now inversion Hlookup. }          
          assert (is_true (@firstorder_oneind [] mind Eind)).
          { clear - HEind Hfo; eapply forallb_nth_error with (n := ind) in Hfo.
            rewrite HEind in Hfo. exact Hfo. }
          unshelve erewrite CoqType_to_camlType'_nth; try eapply e; eauto.
          2: { rewrite CoqType_to_camlType'_length in Hind. lia. }
          unfold blocks_until.
          unshelve erewrite filter_length_not_nil with (mind:=mind) (ind:=ind); eauto.
          unshelve erewrite CoqType_to_camlType'_nth; try eapply e; eauto.
          2: { rewrite CoqType_to_camlType'_length in Hind. lia. }
          econstructor.
          - apply Forall2_acc_cst. 
            rewrite MCList.map_InP_spec.
            rewrite <- (map_id v'). apply Forall2_map. 
            rewrite Forall2_map_left. 
            epose (Forall2_map_right (fun a b =>
            eval [] empty_locals h
              (compile_pipeline Σ a.1) h b) fst _ _). destruct i as [? ?].
            eapply H2 in Heval. 
            rewrite zip_fst in Heval; eauto. 
          - cbn. erewrite <- Forall2_length; eauto.
            clear Heval. eapply In_nth_error in HTs.
            destruct HTs as [k HTs]. pose proof (HEind' := HEind).
            unshelve erewrite CoqType_to_camlType'_nth in HTs; eauto.
            2: { rewrite CoqType_to_camlType'_length in Hind. lia. }                  
            eapply CoqType_to_camlType_oneind_nth in HTs.
            destruct HTs as [l' [HTs Hlength]].
            rewrite Hlength. eapply ctors_max_length; eauto.
        }
        2: { 
        clear Hv' Heval.  
        destruct Hwit as [Ts' [HTs'' [Hfilter _]]].
        pose proof (Hlookup':=Hlookup).
        unfold lookup_inductive, lookup_inductive_gen, lookup_minductive_gen in Hlookup.
        cbn in Hlookup. rewrite ReflectEq.eqb_refl in Hlookup.
        assert (HEind : nth_error (ind_bodies mind) ind = Some Eind).
        { destruct (nth_error (ind_bodies mind) ind); now inversion Hlookup. }
        assert (is_true (@firstorder_oneind [] mind Eind)).
        { clear - HEind Hfo; eapply forallb_nth_error in Hfo; erewrite HEind in Hfo; exact Hfo. }
        unshelve erewrite CoqType_to_camlType'_nth in Hfilter, HTs,HTs', HTs''; eauto.
        2-5 : rewrite CoqType_to_camlType'_length in Hind; lia.
        unfold CoqType_to_camlType_oneind in Hfilter, HTs, HTs', HTs''. remember Eind as o. destruct o. 
        destruct andb_and. destruct (a _).  
        apply CoqType_to_camlType_ind_ctors_nth in HTs''.
        destruct HTs'' as [a0 [? [? ?]]]. rewrite Nat.sub_0_r in HTs'. rewrite HTs' in Hfilter.
        pose proof (i0' := i0). unshelve eapply nth_error_forallb in i0'; eauto.    
        unshelve epose proof (PCUICInductiveInversion.declared_constructor_valid_ty (Σ, univ_decl) [] mind Eind  
        {| inductive_mind := kn; inductive_ind := ind |} k' a0 [] _ _); eauto.
        destruct X as [sctype Hctype].
        { rewrite <- Heqo. cbn. econstructor; eauto. econstructor; eauto.
          unfold declared_minductive. cbn. now left. }
        { unfold consistent_instance_ext, consistent_instance; cbn. now rewrite Hmono. }
        inversion Hfilter. clear HTs HTs' Hfilter. rewrite H4 in Hlv', Hv'Ts. clear T Ts H4.  
        set (P := (fun a b => 0 <= a /\ a < #|ind_bodies mind| /\ b = Rel (#|ind_bodies mind| - S a))). 
        epose proof (Forall2_map_right (fun a => P (snd a)) snd). unfold P in H3.
        rewrite <- H3 in Hlv'. clear H3.
        epose proof (Forall2_map_left P snd). unfold P in H3.
        rewrite <- H3 in Hlv'. clear H3 P. 
        rewrite zip_snd in Hlv'; eauto. 
        eapply Forall2_All2 in Hlv'. revert Hvallv'; intro. 
        assert (Hcstr_indices : cstr_indices a0 = []).
          { apply length_nil. erewrite @cstr_indices_length with (Σ:=Σ) (ind:=(mkInd kn ind,k')); eauto. 
            2: { repeat split. cbn. left. reflexivity. all:cbn; eauto. } cbn. eapply nth_error_forall in Hindices; eauto.
                 cbn in Hindices. now rewrite Hindices. }
        eapply All_sq in Hvallv'. sq. eapply PCUICGeneration.type_mkApps.
        ++ eapply type_Construct; eauto. 
          ** unfold declared_constructor, declared_inductive. now cbn.
          ** unfold consistent_instance_ext, consistent_instance; cbn.
             now rewrite Hmono. 
        ++ unfold PCUICTyping.wf in wfΣ. inversion wfΣ as [_ wfΣ'].
          cbn in wfΣ'. inversion wfΣ'. clear X. inversion X0. inversion on_global_decl_d.
          eapply Alli_nth_error in onInductives; eauto. cbn in onInductives.
          inversion onInductives. unfold PCUICGlobalMaps.on_constructors in *. cbn in *.
          unfold type_of_constructor. cbn.
          eapply All2_nth_error_Some  in onConstructors; eauto.
          destruct onConstructors as [l' [? onConstructor]].          
          pose proof (Hlets := on_lets_in_type _ _ _ _ _ _ _ _ _ onConstructor). cbn in Hlets. 
          revert Hctype. erewrite cstr_eq; eauto. rewrite Hparam. cbn. 
          unfold cstr_concl, cstr_concl_head. 
          rewrite Hparam Hcstr_indices. cbn. rewrite <- plus_n_O. intro.  
          revert Hvallv'; intro.   
          eapply @All_All2_refl with (R := fun a b: term * nat =>
            (Σ, univ_decl);;; []
             |- fst a : tInd {| inductive_mind := kn;
             inductive_ind := #|ind_bodies mind| - S (snd b) |} []) in Hvallv'.
          eapply @All2_map_left with (P := fun a b =>
            (Σ, univ_decl);;; []
             |- a : tInd {| inductive_mind := kn;
                   inductive_ind := #|ind_bodies mind| - S (snd b) |} []) in Hvallv'.
          eapply @All2_map_right with (P := fun a b =>
            (Σ, univ_decl);;; []
                     |- a : tInd {| inductive_mind := kn; inductive_ind := #|ind_bodies mind| - S b |} []) in Hvallv'.
          set (lind := map snd lv') in *. set (lterm := map fst lv') in *. clearbody lterm lind. clear Hexpand' lv'.
          revert Hlv'; intro. rewrite H2 in Hlv'. clear H2. revert x Hlv'. rewrite Hparam app_nil_r. intros. 
          epose (Hnd := firstorder_nonDepProd). edestruct Hnd as [Hnd' [Hndfst Hndsnd]]; eauto.
          1: eapply firstorder_con_notApp; eauto.
          rewrite <- Hndsnd. eapply nonDep_typing_spine with (s:=sctype) ; eauto. 
          { revert Hctype; intro. unfold type_of_constructor in Hctype. cbn in Hctype.
            erewrite cstr_eq in Hctype; eauto. rewrite Hparam in Hctype. cbn in Hctype. 
            unfold cstr_concl, cstr_concl_head in Hctype. rewrite Hparam Hcstr_indices app_nil_r in Hctype.
            cbn in Hctype. rewrite <- plus_n_O in Hctype. eauto. }
          rewrite Hndfst. now apply All2_map_right. }

      pose (MCList.nth_error_spec (ind_bodies mind) ind).
      destruct n; cbn; intros.
        2: { rewrite CoqType_to_camlType'_length in Hind. lia. } 
      pose (MCList.nth_error_spec (ind_ctors x) k').
      assert (Hfo_x : is_true (@firstorder_oneind [] mind x)).
        { clear -e Hfo; eapply forallb_nth_error in Hfo; erewrite e in Hfo; exact Hfo. }
      destruct n; intros; eauto.
        2: { 
          unshelve erewrite CoqType_to_camlType'_nth in Hk'; eauto.
          rewrite CoqType_to_camlType_oneind_length in Hk'.
          lia. }
      destruct Hwit as [As [Ha [Ha' _]]].
      eapply PCUICEtaExpand.expanded_tConstruct_app with (mind := mind) (idecl := _) (cdecl := _).
      3: { now rewrite Forall_map. }
      { unfold declared_constructor, declared_inductive. now cbn. }
      unshelve erewrite CoqType_to_camlType'_nth in Ha; eauto.
      assert (Hcstr: forall b n, nth_error (ind_ctors x) n = Some b -> #|cstr_args b| = context_assumptions (cstr_args b)). 
      { intros b m Hx; assert (declared_constructor Σ ({| inductive_mind := kn; inductive_ind := ind |}, m) mind x b).
        { split; eauto. split; eauto. simpl. now left. }
          apply is_assumption_context_length.
          eapply PCUICWeakeningEnvTyp.on_declared_constructor in H0 as [? [? ?]].
          eapply All2_In in onConstructors as [[univs onConstructor]].
          2: { now eapply nth_error_In. }
          now eapply on_lets_in_type in onConstructor.
       } 

      rewrite Hnparam. erewrite <- Hcstr; eauto. cbn. rewrite map_length.
      pose proof (Forall2_length Hlv').  rewrite zip_length in H0; eauto. rewrite H0. clear H0.
      rewrite Nat.sub_0_r in HTs'. rewrite Ha' in HTs'. 
      eapply CoqType_to_camlType_oneind_nth in Ha as [? [? ?]].
      rewrite e0 in H0. inversion H0; inversion HTs'. subst. lia.
  Qed.

  Lemma realize_adt_value_fo {funext:Funext} {P : Pointer} {H : CompatiblePtr P P}  {HP : @Heap P} `{@CompatibleHeap P P _ _ _} 
    `{WcbvFlags} (cf:=config.extraction_checker_flags)
    univ retro univ_decl kn mind
    (Hparam : ind_params mind = [])
    (Hindices : Forall (fun ind => ind_indices ind = []) (ind_bodies mind))
    (Hnparam : ind_npars mind = 0)
    (Hmono : ind_universes mind = Monomorphic_ctx)
    (Hheap_refl : forall h, R_heap h h)
    (empty_heap : heap)
    (Hfo : is_true (forallb (@firstorder_oneind [] mind) (ind_bodies mind))) :
    let adt := CoqType_to_camlType mind Hparam Hfo in
    let Σ : global_env_ext_map := (build_global_env_map (mk_global_env univ [(kn , InductiveDecl mind)] retro), univ_decl) in
    pcuic_good_for_extraction Σ ->
    PCUICTyping.wf Σ ->
    with_constructor_as_block = true ->
    forall v ind Eind, 
    ind < List.length (snd adt) ->
    lookup_inductive Σ (mkInd kn ind) = Some (mind, Eind) ->
    forall n, 
    realize_ADT_gen _ _ [] [] adt n [] All_nil ind v ->
    realize_value _ _ [] (to_list (realize_ADT_gen P HP [] [] adt n [] All_nil ) #|ind_bodies mind|) [] (Rel ind) v.
  Proof.
    intros ? ? ? wfΣ ? ? ? ? Hind Hlookup n Hadt. 
    pose proof (Heval := ex_intro _ n Hadt : realize_ADT P HP [] [] adt [] All_nil ind v).
    eapply camlValue_to_CoqValue in Heval as [t [Hexp [wt Heval]]]; eauto.
    intro h. eexists; exists h; split; eauto. clear h. 
    intros h h' v' Heval'. rewrite to_list_nth. { unfold adt in Hind. cbn in Hind. now rewrite CoqType_to_camlType'_length in Hind. }
    unshelve eapply isPure_heap_irr in Heval'; eauto.
    2: apply compile_pure.
    2: econstructor.
    unshelve eapply eval_det in Heval' as [_ Hrel];  try eapply Heval; eauto.
    3: econstructor.
    2: { intros ? ? ? X; inversion X. } 
    unshelve eapply isPure_value_vrel_eq in Hrel; eauto.
    2: { unshelve eapply isPure_heap; try apply Heval; eauto; try econstructor. apply compile_pure. }
    now subst.
  Qed.

  Parameter verified_malfunction_pipeline_theorem : forall `{Heap} `{Pointer} `{WcbvFlags} (efl := extraction_env_flags) (cf := extraction_checker_flags)
  univ retro univ_decl kn mind
  (Hparam : ind_params mind = [])
  (Hindices : Forall (fun ind => ind_indices ind = []) (ind_bodies mind))
  (Hnparam : ind_npars mind = 0)
  (Hmono : ind_universes mind = Monomorphic_ctx)
  (Σ0 := mk_global_env univ [(kn , InductiveDecl mind)] retro)
  (Hfo : is_true (forallb (@firstorder_oneind (firstorder_env (Σ0 , univ_decl)) mind) (ind_bodies mind))),
  let adt := CoqType_to_camlType mind Hparam Hfo in
  let Σ : global_env_ext_map := (build_global_env_map Σ0, univ_decl) in
  forall (HΣ : PCUICTyping.wf_ext Σ),
  with_constructor_as_block = true ->
  forall t ind Eind, 
  ind < List.length (snd adt) ->
  lookup_inductive Σ (mkInd kn ind) = Some (mind, Eind) ->
  forall (wt : Σ ;;; [] |- t : tInd (mkInd kn ind) [])
  (expΣ : PCUICEtaExpand.expanded_global_env Σ)
  (expt : PCUICEtaExpand.expanded Σ [] t), 
  forall h v (Heval : ∥PCUICWcbvEval.eval Σ t v∥),  
  let Σb := (Transform.transform verified_named_erasure_pipeline (Σ, v) (ErasureCorrectness.precond2 _ _ _ _ expΣ expt wt Normalisation _ Heval)).1 in
  ∥ eval [] (fun _ => fail "notfound") h (compile_pipeline Σ t) h (compile_value_mf' _ Σ Σb v)∥.

  Parameter verified_named_erasure_pipeline_fo : forall `{Heap} `{Pointer} `{WcbvFlags} (efl := extraction_env_flags) (cf := extraction_checker_flags)
  univ retro univ_decl kn mind
  (Hparam : ind_params mind = [])
  (Hindices : Forall (fun ind => ind_indices ind = []) (ind_bodies mind))
  (Hnparam : ind_npars mind = 0)
  (Hmono : ind_universes mind = Monomorphic_ctx)
  (Σ0 := mk_global_env univ [(kn , InductiveDecl mind)] retro)
  (Hfo : is_true (forallb (@firstorder_oneind (firstorder_env (Σ0 , univ_decl)) mind) (ind_bodies mind))),
  let adt := CoqType_to_camlType mind Hparam Hfo in
  let Σ : global_env_ext_map := (build_global_env_map Σ0, univ_decl) in
  forall (HΣ : PCUICTyping.wf_ext Σ),
  with_constructor_as_block = true ->
  forall t ind Eind, 
  ind < List.length (snd adt) ->
  lookup_inductive Σ (mkInd kn ind) = Some (mind, Eind) ->
  forall (wt : Σ ;;; [] |- t : tInd (mkInd kn ind) [])
  (expΣ : PCUICEtaExpand.expanded_global_env Σ)
  (expt : PCUICEtaExpand.expanded Σ [] t), 
  forall v Heval,
  let Σb := (Transform.transform verified_named_erasure_pipeline (Σ, v) (ErasureCorrectness.precond2 _ _ _ _ expΣ expt wt Normalisation _ Heval)).1 in
  ErasureCorrectness.firstorder_evalue_block Σb (ErasureCorrectness.compile_value_box Σ v []).
  
  Lemma firstn_firstn_length {A} (l : list A) n l' : n <= #|l| -> firstn n (firstn n l ++ l') = firstn n l.
  Proof.
    induction l in n |- *; simpl; auto.
    destruct n=> /=; auto. inversion 1. 
    destruct n=> /=; auto. intros.
    assert (n<=#|l|) by lia. now rewrite IHl.
  Qed.

  Definition isConstruct_ind t :=
  match fst (PCUICAstUtils.decompose_app t) with
  | tConstruct i _ _ => inductive_ind i
  | _ => 0
  end.

Fixpoint Forall_exists T A P l
  (H : Forall (fun (t : T) => exists a : A, P t a) l) : exists l' : list A, Forall2 (fun t a => P t a) l l'.
Proof. 
destruct H.
- exists []. econstructor.
- destruct H as [p H].
  refine (let '(ex_intro l' X) := 
          Forall_exists T A P _ H0 in _).
  exists (p::l'). econstructor; eauto. 
Qed. 

Lemma to_list_nth_def {A} (f : nat -> A) (size : nat) n d : 
  n >= size ->  
  nth n (to_list f size) d = d.
Proof.
  intro. apply nth_overflow. rewrite to_list_length. lia.  
Qed. 

Lemma realize_term_mono {P : Pointer} {HP : @Heap P}
  (local_adt local_adt' : nat -> value -> Prop) T t k :
  (forall k v, local_adt k v -> local_adt' k v) ->
  ~~ isArrow T ->
  realize_term P HP [] (to_list local_adt k) [] T t ->
  realize_term P HP [] (to_list local_adt' k) [] T t.
Proof.
  revert T t k.
  refine (camlType_rect _ _ _ _); intros; simpl in *. 
  - inversion H2. 
  - case_eq (n <? k).
      * intro e'. apply Nat.leb_le in e'.
        rewrite to_list_nth; [lia|]. rewrite to_list_nth in H1; [lia|].
        intros h h' v. now specialize (H1 h h' v).
      * intro e'. apply Nat.ltb_ge in e'. 
        rewrite to_list_nth_def; eauto. 
        rewrite to_list_nth_def in H1; eauto. 
  - inversion H1.
Qed.

Lemma realize_ADT_mono {P : Pointer} {HP : @Heap P} n :
  forall adt ind v m (params:=[]) (paramRel:=All_nil)
  (Harrow : forall lind larg T , In lind adt ->
  In larg lind -> In T larg -> ~~ isArrow T),
  n <= m -> realize_ADT_gen_fix _ _ [] [] adt n params paramRel ind v
  -> realize_ADT_gen_fix _ _ [] [] adt m params paramRel ind v.
Proof. 
  induction n; intros ? ? ? ? ? ? ?; destruct m; intros e Hn.
  1,2: cbn in *; inversion Hn.
  1: solve [inversion e]. 
  assert (n <= m) by lia.
  cbn in *. 
  case_eq (ind <? #|adt|). 2: intro He; rewrite He in Hn; inversion Hn.
  intro He; rewrite He in Hn. eapply Nat.leb_le in He. 
  destruct Hn; [left; eauto | right].
  set (nth ind _ _) in *.  
  rewrite Existsi_spec. rewrite Existsi_spec in H0.
  destruct H0 as [k [T [? [? [[? [? ?]] ?]]]]].
  repeat eexists; eauto.
  epose proof (nth_In adt [] He).
  assert (In T y).
  { eapply nth_error_In in H4. now eapply filter_In in H4. }
  pose proof (fun A => Harrow _ _ A H5 H6).
  assert (Forall2 (fun A _ => ~~isArrow A) T x).
  { clear - H7 H3. revert x H3. induction T; intros; inversion H3; econstructor; eauto; subst.
    eapply H7. now left. eapply IHT; eauto. intros; eapply H7. cbn. now right. }
  eapply Forall2_and in H3; try apply H8. clear H7 H8.
  eapply Forall2_impl; try eapply H3.
  intros. intro h. cbn in H7. destruct H7 as [? H7].
  specialize (H7 h) as [t [h' [? ?]]]. exists t, h'; split; eauto.
  eapply realize_term_mono; try apply H9; eauto.
Qed.

Lemma CoqType_to_camlType_fo_irr Σb Σb' mind Hparam 
  (Hfo : is_true (forallb (@firstorder_oneind Σb mind) (ind_bodies mind)))
  (Hfo' : is_true (forallb (@firstorder_oneind Σb' mind) (ind_bodies mind))) :       
  CoqType_to_camlType' mind Hparam Hfo = CoqType_to_camlType' mind Hparam Hfo'.
Proof.  
  destruct mind; cbn in *. 
  revert Hfo Hfo'.
  enough (forall ind_bodies1
  (Hfo : forallb
            (@firstorder_oneind Σb
               {|
                 PCUICExpandLetsCorrectness.T.PCUICEnvironment.ind_finite := ind_finite0;
                 PCUICExpandLetsCorrectness.T.PCUICEnvironment.ind_npars := ind_npars0;
                 PCUICExpandLetsCorrectness.T.PCUICEnvironment.ind_params := ind_params0;
                 PCUICExpandLetsCorrectness.T.PCUICEnvironment.ind_bodies := ind_bodies1;
                 PCUICExpandLetsCorrectness.T.PCUICEnvironment.ind_universes := ind_universes0;
                 PCUICExpandLetsCorrectness.T.PCUICEnvironment.ind_variance := ind_variance0
               |}) ind_bodies0)
  (Hfo' : forallb
            (@firstorder_oneind Σb'
               {|
                 PCUICExpandLetsCorrectness.T.PCUICEnvironment.ind_finite := ind_finite0;
                 PCUICExpandLetsCorrectness.T.PCUICEnvironment.ind_npars := ind_npars0;
                 PCUICExpandLetsCorrectness.T.PCUICEnvironment.ind_params := ind_params0;
                 PCUICExpandLetsCorrectness.T.PCUICEnvironment.ind_bodies := ind_bodies1;
                 PCUICExpandLetsCorrectness.T.PCUICEnvironment.ind_universes := ind_universes0;
                 PCUICExpandLetsCorrectness.T.PCUICEnvironment.ind_variance := ind_variance0
               |}) ind_bodies0),
CoqType_to_camlType_fix ind_bodies0 ind_finite0 ind_params0 ind_npars0 ind_universes0 ind_variance0 Hparam
  ind_bodies1 Hfo =
CoqType_to_camlType_fix ind_bodies0 ind_finite0 ind_params0 ind_npars0 ind_universes0 ind_variance0 Hparam
  ind_bodies1 Hfo').
  { intros; eauto. }
  
  induction ind_bodies0; cbn; intros; eauto.
  repeat destruct andb_and; cbn in *. destruct (a0 _). destruct (a1 _). clear a0 a1. 
  f_equal; eauto.
  destruct a; cbn in *.
  repeat destruct andb_and; cbn in *. destruct (a _). destruct (a0 _). clear. 
  induction ind_ctors0; cbn; eauto. destruct a. 
  repeat destruct andb_and; cbn in *. destruct (a _). destruct (a0 _). clear a a0.
  f_equal; eauto. revert i1 i3. clear. 
  set (l := rev _). clearbody l. generalize 0. induction l; cbn; intros; eauto.
  destruct a. repeat destruct andb_and; cbn in *. destruct (a _). destruct (a0 _).
  f_equal; eauto. clear. revert i2 i5. unfold firstorder_type, CoqType_to_camlType_oneind_type.
  set (PCUICAstUtils.decompose_app decl_type). clearbody p. destruct p.
  cbn; intros. destruct t; eauto. now destruct ind.
  Qed. 

Lemma CoqValue_to_CamlValue {funext : Funext} {P : Pointer} {H : CompatiblePtr P P} (cf := extraction_checker_flags)
  (efl := EInlineProjections.switch_no_params EWellformed.all_env_flags)  {has_rel : EWellformed.has_tRel} {has_box : EWellformed.has_tBox}  
  {HP : @Heap P} `{@CompatibleHeap P P _ _ _} `{WcbvFlags} `{EWellformed.EEnvFlags}
  univ retro univ_decl kn mind
  (Hheap_refl : forall h, R_heap h h)
  (Hparam : ind_params mind = [])
  (Hindices : Forall (fun ind => ind_indices ind = []) (ind_bodies mind))
  (Hnparam : ind_npars mind = 0)
  (Hind : ind_finite mind == Finite )
  (Hmono : ind_universes mind = Monomorphic_ctx)
  (Σ0 := mk_global_env univ [(kn , InductiveDecl mind)] retro)
  (Hgood : pcuic_good_for_extraction Σ0)
  (Hfo_nil : is_true (forallb (@firstorder_oneind [] mind) (ind_bodies mind))) :
  let adt := CoqType_to_camlType mind Hparam Hfo_nil in
  let Σ : global_env_ext_map := (build_global_env_map Σ0, univ_decl) in
  PCUICTyping.wf_ext Σ ->
  with_constructor_as_block = true ->
  forall t ind Eind, 
(*  ind < List.length (snd adt) -> *)
  lookup_inductive Σ (mkInd kn ind) = Some (mind, Eind) ->
  forall (wt : Σ ;;; [] |- t : tInd (mkInd kn ind) [])
  (expΣ : PCUICEtaExpand.expanded_global_env Σ)
  (expt : PCUICEtaExpand.expanded Σ [] t),
    realize_term P HP [] (to_list (realize_ADT P HP [] [] adt [] All_nil ) #|ind_bodies mind|) [] (Rel ind) (compile_pipeline Σ t).
  Proof.
    intros ? ? HΣ ? ? ? ? Hlookup ? ? ? ? ? ? Heval_compile.
    pose proof Normalisation.   
    assert (Hfo : is_true (forallb (@firstorder_oneind (firstorder_env (Σ0 , univ_decl)) mind) (ind_bodies mind))).
    { assert (@firstorder_mutind (firstorder_env (Σ0 , univ_decl)) mind).
      { eapply (firstorder_mutind_ext (Σ':=(mk_global_env univ [] retro ,univ_decl))). 3: rewrite andb_and; split; eauto.
        2: eauto. 2: now destruct mind, ind_finite0. repeat econstructor. rewrite app_nil_r. reflexivity. }
      unfold firstorder_mutind in H5. now rewrite andb_and in H5. }
    assert (Hax: PCUICClassification.axiom_free Σ).
    { intros ? ? X. now inversion X. }
    assert (Hindlt : ind < #|(CoqType_to_camlType mind Hparam Hfo).2|).
    { rewrite CoqType_to_camlType'_length. unfold lookup_inductive, lookup_inductive_gen, lookup_minductive_gen in Hlookup.
      destruct (lookup_env _ _); [|inversion Hlookup]. destruct g; [inversion Hlookup|].
      eapply nth_error_Some_length; eauto. cbn in Hlookup. 
      case_eq (nth_error (ind_bodies m) ind); [intros ? e | intro e] ; rewrite e in Hlookup; inversion Hlookup; subst. 
      rewrite e. reflexivity. }  
    unshelve epose proof (PCUICNormalization.wcbv_normalization HΣ _ wt) as [val Heval]; eauto.
    unshelve epose proof (wval := PCUICClassification.subject_reduction_eval wt Heval).
    unshelve epose proof (Heval' := fun h => verified_malfunction_pipeline_theorem univ retro univ_decl kn mind Hparam Hindices Hnparam 
    Hmono Hfo HΣ _ t ind Eind _ _ wt expΣ expt h _ (sq Heval)); eauto. 
    unshelve epose proof (Hfo' := verified_named_erasure_pipeline_fo univ retro univ_decl kn mind Hparam Hindices Hnparam 
    Hmono Hfo HΣ _ t ind Eind _ _ wt expΣ expt _ (sq Heval)); eauto.
    assert (Hval_fo : firstorder_value Σ [] val).
    { eapply firstorder_value_spec with (args := []); eauto. 
      - now eapply PCUICWcbvEval.eval_to_value.
      - unfold firstorder_ind; cbn. rewrite ReflectEq.eqb_refl.
        unfold firstorder_mutind. rewrite andb_and. split; eauto. 
        now destruct ind_finite. } 


    Opaque verified_named_erasure_pipeline.
    rewrite -/ Σ in Heval', Hfo'. cbn in Heval'. sq. 
    assert (Hindval : isConstruct_ind val = ind).
    { pose proof (Hsub := PCUICClassification.subject_reduction_eval wt Heval).  
      eapply PCUICClassification.ind_whnf_classification with (indargs := []) in Hsub; eauto.
      2: { intro Hcof. cbn in Hcof. 
           unfold check_recursivity_kind in Hcof. cbn in Hcof. rewrite ReflectEq.eqb_refl in Hcof.
           clear - Hcof Hind. now destruct ind_finite. }
      2: { eapply PCUICClassification.eval_whne; eauto. eapply (PCUICClosedTyp.subject_closed (Γ :=[])); eauto. }
      pose proof (Hdecomp := PCUICAstUtils.mkApps_decompose_app val).
      rewrite Hdecomp in wval.
      unfold PCUICAstUtils.isConstruct_app in Hsub. unfold isConstruct_ind.
      destruct (PCUICAstUtils.decompose_app val).1; inversion Hsub.
      unshelve eapply PCUICInductiveInversion.Construct_Ind_ind_eq' with (args' := []) in wval; eauto.
      repeat destruct wval as [? wval]. repeat destruct p.
      subst. reflexivity. }
    rewrite - Hindval.
    rewrite (compile_value_mf_eq _ _ _ _ _ _ _ _ _ _ [] wt) in Heval'; eauto.  
    { intros. cbn in H5. destruct (i == _); inversion H5. now subst. }
    epose proof (Hlookup_Σ := verified_named_erasure_pipeline_lookup_env_in _ _ _ HΣ expΣ _ expt val {| inductive_mind := kn; inductive_ind := ind |} []
      [] wt Normalisation (sq Heval) kn).
    set (Σval := (Transform.transform verified_named_erasure_pipeline (Σ, val) _).1) in *. 
    clearbody Σval. rewrite - Hindval in Hindlt. 

    rewrite to_list_nth. { now rewrite CoqType_to_camlType'_length in Hindlt. } 
    specialize (Heval' h). sq. cbn in Heval_compile. 
    eapply eval_det in Heval'; try eapply Heval_compile; eauto. 
    2: { intros ? ? ? X. inversion X. }
    2: { econstructor. }
    destruct Heval' as [_ Heval'].

    epose proof (compile_pure Σ0 t). 
    eapply isPure_heap in H5 as [Hpure _]; eauto. 
    2: { intro. econstructor. }
    
    unshelve eapply isPure_value_vrel_eq in Heval'; eauto.
    subst. 


    clear wt t expt Heval wval Hlookup Eind Heval_compile Hpure.  
    revert adt Hindlt Hfo'.

    unfold realize_ADT. enough 
    ( exists n, isConstruct_ind val < #|(CoqType_to_camlType mind Hparam Hfo).2| ->
       ErasureCorrectness.firstorder_evalue_block Σval (ErasureCorrectness.compile_value_box Σ val []) ->
       realize_ADT_gen P HP [] [] (CoqType_to_camlType mind Hparam Hfo_nil) n [] All_nil (isConstruct_ind val)
       (CompileCorrect.compile_value Σval (compile_named_value Σ val))).
    { destruct H5 as [n ?]. intros; now exists n. }

    unshelve eapply (firstorder_value_inds Σ [] (fun val => _) _ val Hval_fo). clear val Hval_fo.
    intros ? ? ? ? ? ? wtv Hargs_fo Hrec _. 

    eapply Forall_exists in Hrec as [ns Hrec]. exists (S (list_max ns)); intros Hindlt Hfo_blocks.
     
    revert Hindlt. unfold isConstruct_ind. rewrite PCUICAstUtils.decompose_app_mkApps; cbn; eauto; intro. 
    
    set (tv := mkApps (tConstruct i n ui) args) in *. 
    epose proof (Hdecomp := PCUICAstUtils.decompose_app_mkApps (tConstruct i n ui) args).
    forward Hdecomp; eauto. 

    pose proof (wval := wtv). unfold tv in wval.  
    eapply PCUICInductiveInversion.Construct_Ind_ind_eq' in wval; eauto.
    (* destruct wval as [mdecl [idecl [cdecl wval]]].
    destruct wval as [Hdecl [? ?]].
    destruct s as [parsubst [argsubst [parsubst' [argsubst' ?]]]].
    cbn in a. destruct a as [s0 s1 s2 s3]. destruct s2.  *)  
    repeat destruct wval as [? wval]. repeat destruct p.
    subst. simpl in *.
    destruct d as [[dx dx0] d]. cbn in dx, dx0, d. 
    destruct dx as [dx | dx]; inversion dx. symmetry in H7. subst. clear dx.
    clear x2 x3 x4 x5 s0 s1 s2 s spine_dom_wf inst_ctx_subst inst_subslet c c0. 

    inversion Hfo_blocks as [? ? ? Hlookup' HForall_fo Heq]. clear Hfo_blocks.
    unfold tv, compile_named_value in Heq.  erewrite compile_value_box_mkApps in Heq. cbn in Heq.
    unfold ErasureCorrectness.pcuic_lookup_inductive_pars, EGlobalEnv.lookup_constructor_pars_args in *. 
    cbn in Hlookup'.
    set (EGlobalEnv.lookup_env _ _) in Hlookup'.  
    case_eq o. 2: { intro X0. rewrite X0 in Hlookup'. inversion Hlookup'. }
    intros g Hg; rewrite Hg in Hlookup'. 
    destruct g. { inversion Hlookup'. }   
    cbn in *. rewrite ReflectEq.eqb_refl in Heq; inversion Heq.
    subst. clear Heq. unfold o in Hg. cbn in *. 
    pose proof (Hdecl := Hg).
    eapply Hlookup_Σ in Hg. 
    destruct Hg as [decl' [Hlookup_decl Hdecl']]. rewrite ReflectEq.eqb_refl in Hlookup_decl. 
    inversion Hlookup_decl. subst. clear Hlookup_decl.
    cbn in Hlookup'. rewrite map_mapi nth_error_mapi in Hlookup'.

    rewrite CoqType_to_camlType'_length.
    assert (Hind' : inductive_ind i <? #|ind_bodies mind|). 
    { rewrite CoqType_to_camlType'_length in Hindlt. now apply Nat.leb_le. }
    rewrite Hind'. case_eq (nth_error (ind_bodies mind) (inductive_ind i)).
    2:{ intro Hnone. rewrite Hnone in Hlookup'. inversion Hlookup'. }
    intros indbody Hindbody. rewrite Hindbody in Hlookup'.
    assert (x0 = indbody). { now clear -dx0 Hindbody. } subst.
    assert (Hcstr: forall x n, nth_error (ind_ctors indbody) n = Some x -> #|cstr_args x| = cstr_arity x). 
    { intros x m Hx; assert (declared_constructor Σ (i, m) mind indbody x).
      { split; eauto. split; eauto. simpl. now left. }
        erewrite <- ErasureCorrectness.declared_constructor_arity; eauto.
        eapply PCUICWeakeningEnvTyp.on_declared_constructor in H5
        as [? [? ?]].
        eapply All2_In in onConstructors as [[univs onConstructor]].
        2: { now eapply nth_error_In. }
        eapply on_lets_in_type in onConstructor.
        now apply is_assumption_context_length.
     } 
        
    cbn in Hlookup'. repeat rewrite nth_error_map in Hlookup'. 
    rewrite d in Hlookup'. cbn in Hlookup'.
    destruct args. 
    - left. cbn in *. unfold ErasureCorrectness.pcuic_lookup_inductive_pars. cbn. rewrite ReflectEq.eqb_refl. cbn. 
      unfold Compile.lookup_constructor_args, EGlobalEnv.lookup_inductive. cbn. rewrite Hdecl. cbn.   
      rewrite nth_error_map nth_error_mapi.  rewrite Hindbody. cbn. rewrite Hnparam skipn_0. cbn. 
      assert (forall l, 
       (forall x n, nth_error l n = Some x -> #|cstr_args x| = cstr_arity x) ->
        #|filter (fun x : nat => match x with | 0 => true | S _ => false end)
      (map EAst.cstr_nargs
      (map (fun cdecl : constructor_body => {| Extract.E.cstr_name := cstr_name cdecl; Extract.E.cstr_nargs := cstr_arity cdecl |})
      (map (PCUICExpandLets.trans_constructor_body (inductive_ind i) mind) l)))| = 
      #|filter (fun x : nat => match x with | 0 => true | S _ => false end) (map cstr_nargs l)|).
      {
        induction l; intros Hl; [eauto|cbn in *]. 
        assert (cstr_arity a = #|cstr_args a|). { symmetry; now eapply (Hl _ 0). }
        destruct a; cbn in *.   
        rewrite <- H5. destruct cstr_arity0; cbn; [f_equal |]; eapply IHl. 
        all: intros; now eapply (Hl _ (S n0)). 
      }
      repeat rewrite firstn_map. erewrite H5; eauto.
      2: { intros. eapply (Hcstr _ n0). now eapply nth_error_firstn. }
      rewrite -firstn_map. clear H5. 
      unshelve erewrite filter_length_nil. 5:eauto. 4:eauto. eauto.
      assert (CoqType_to_camlType' mind Hparam Hfo = CoqType_to_camlType' mind Hparam Hfo_nil) by apply CoqType_to_camlType_fo_irr.
      rewrite -H5. clear H5.  
      unshelve erewrite CoqType_to_camlType'_nth.
      4: eauto. 3: { now apply Nat.leb_le. }
      { eapply nth_error_forallb; eauto. } 
      pose proof (Hx1 := d).
      unshelve eapply CoqType_to_camlType_oneind_nth' in d as [l' [d ?]]; eauto.  
      2: eapply nth_error_forallb; eauto. 
      pose proof (Hd := PCUICReduction.nth_error_firstn_skipn d).
      rewrite Hd.
      set (CoqType_to_camlType_oneind _ _ _ _) in *.
      rewrite firstn_firstn_length. { eapply nth_error_Some_length in d. lia. } 
      assert (l' = []). 
      { apply length_zero_iff_nil. inversion Hlookup'. rewrite H5. 
        rewrite Hnparam in H7. rewrite skipn_0 in H7. erewrite Hcstr; eauto. }  
      set (k := #|_|). set (f := fun x : list camlType => _). set (ll := _ ++ _).
      epose proof (filter_firstn' _ k f ll) as [? [_ [? [? [? [? ?]]]]]].
      { unfold k, f, ll. rewrite filter_app. cbn. rewrite H6. rewrite app_length. cbn. lia. }
      apply Existsi_spec. repeat eexists; cbn; try lia.
      unfold k, f, ll. rewrite filter_app. cbn. subst. rewrite app_length. cbn. lia.
      rewrite Nat.sub_0_r. eauto. 

    - set (args' := t :: args) in *. unfold tv.
      right. cbn in Hlookup'.  rewrite Hnparam skipn_0 in Hlookup'. cbn in Hlookup'.
      unfold compile_named_value. erewrite compile_value_box_mkApps. cbn.
      unfold ErasureCorrectness.pcuic_lookup_inductive_pars. cbn. rewrite ReflectEq.eqb_refl. cbn. 
      unfold Compile.lookup_constructor_args, EGlobalEnv.lookup_inductive. cbn. rewrite Hdecl. cbn.   
      rewrite nth_error_map nth_error_mapi. rewrite Hindbody. cbn. rewrite Hnparam skipn_0. cbn. 
      assert (CoqType_to_camlType' mind Hparam Hfo = CoqType_to_camlType' mind Hparam Hfo_nil) by apply CoqType_to_camlType_fo_irr.
      rewrite -H5. clear H5.
      unshelve erewrite CoqType_to_camlType'_nth.
      4: eauto. 3: { now apply Nat.leb_le. }
      { eapply nth_error_forallb; eauto. }
      pose proof (Hx1 := d).

      unshelve eapply CoqType_to_camlType_oneind_nth' in d as [l' [d ?]]; eauto.  
      2: eapply nth_error_forallb; eauto.
      
      assert (forall l, 
      (forall x n, nth_error l n = Some x -> #|cstr_args x| = cstr_arity x) ->
      #|filter (fun x : nat => match x with | 0 => false | S _ => true end)
      (map EAst.cstr_nargs
      (map (fun cdecl : constructor_body => {| Extract.E.cstr_name := cstr_name cdecl; Extract.E.cstr_nargs := cstr_arity cdecl |})
      (map (PCUICExpandLets.trans_constructor_body (inductive_ind i) mind) l)))| = 
      #|filter (fun x : nat => match x with | 0 => false | S _ => true end) (map cstr_nargs l)|).
      {
        induction l; intros Hl; [eauto|cbn in *]. 
        assert (cstr_arity a = #|cstr_args a|). { symmetry; now eapply (Hl _ 0). }
        destruct a; cbn in *. rewrite <- H6. destruct cstr_arity0; cbn; [|f_equal]; eapply IHl. 
        all: intros; now eapply (Hl _ (S n0)).
      }
      repeat rewrite firstn_map. erewrite H6.
      2: { intros. eapply (Hcstr _ n0). now eapply nth_error_firstn. }      
      rewrite -firstn_map. clear H6. 
      unshelve erewrite filter_length_not_nil. 4,5,7:eauto.

      unshelve erewrite CoqType_to_camlType'_nth.
      4: eauto. 3: { now apply Nat.leb_le. }
      { eapply nth_error_forallb; eauto. }

      pose proof (Hd := PCUICReduction.nth_error_firstn_skipn d).
      rewrite Hd.

      set (CoqType_to_camlType_oneind _ _ _ _) in *.
      rewrite firstn_firstn_length. { eapply nth_error_Some_length in d. lia. }
      set (k := #| _ |). set (f := fun x : list camlType => _) in *. set (ll := _ ++ _).
      destruct l'. { 
        inversion Hlookup'. 
        erewrite Hcstr in H5; eauto. 
        rewrite - H5 in H7. inversion H7. } 
      epose proof (filter_firstn' _ k f ll) as [? [_ [? [? [? [? ?]]]]]].
      { unfold k, f, ll. rewrite filter_app. cbn. rewrite app_length. cbn. lia. }
      apply Existsi_spec. repeat eexists; cbn; try lia.
      { unfold k, f, ll. rewrite filter_app. cbn. subst. rewrite app_length. cbn. lia. }
      2: { rewrite Nat.sub_0_r. eauto. }
      revert Hrec H7. intros. rewrite - Hd in ll, H6, H8, H7. unfold ll, l in *. clear ll l Hd.
      change (mkApps (tApp (tConstruct i n ui) t) args) with (mkApps (tConstruct i n ui) (t :: args)) in *.
      repeat rewrite map_map. rewrite - (map_cons _ t args).
      rewrite Forall2_map_right. fold args'.
      pose proof (Hx0 := H7). unshelve eapply CoqType_to_camlType_oneind_nth in H7. 
      assert (realize_ADT_gen_fix P HP [] [] (CoqType_to_camlType' mind Hparam Hfo) (list_max ns) [] All_nil = 
      realize_ADT_gen P HP [] [] (CoqType_to_camlType mind Hparam Hfo) (list_max ns) [] All_nil) by reflexivity.
      rewrite H10. clear H10. 
      assert (Forall2 (fun T v => 
        T = (Rel (isConstruct_ind v))) x0 args'). by todo "". 
      assert (Forall (fun v => 
        isConstruct_ind v < #|ind_bodies mind|) args') by todo "". 
      enough 
      (Forall
        (fun (y : term) =>
        realize_value P HP []
         (to_list (realize_ADT_gen P HP [] [] (CoqType_to_camlType mind Hparam Hfo) (list_max ns) [] All_nil)
            #|ind_bodies mind|) [] (Rel (isConstruct_ind y))
         (CompileCorrect.compile_value Σval            
            (eval_fo (ErasureCorrectness.compile_value_box (PCUICExpandLets.trans_global_env Σ0) y [])))) args').
      {
      eapply Forall_mix in H12; try apply H11. clear H11.  
      eapply Forall2_Forall_mix; [| apply H12]. eapply Forall2_impl; eauto. 
        cbn; intros; destruct H13; subst; eauto.
      }
      eapply Forall2_sym in Hrec. 
      assert (Forall
      (fun (y : term) =>
       ErasureCorrectness.firstorder_evalue_block
          Σval
         (ErasureCorrectness.compile_value_box Σ0 y []) ->
       realize_ADT_gen P HP [] [] (CoqType_to_camlType mind Hparam Hfo_nil) (list_max ns) [] All_nil
         (isConstruct_ind y)
         (CompileCorrect.compile_value Σval (compile_named_value Σ y))) args').
      { clear - H11 Hrec. eapply Forall_Forall2_and' in Hrec; [| apply H11]. clear H11.  
        unfold CoqType_to_camlType. cbn. set (list_max _). 
        assert (list_max ns <= n) by lia. clearbody n.
        revert n H. induction Hrec; simpl; econstructor. 
        - intros. eapply realize_ADT_mono; try eapply H; eauto; [|lia|].
          eapply CoqType_to_camlType'_fo. now rewrite CoqType_to_camlType'_length.
        - eapply IHHrec. lia. }
      clear Hrec; rename H12 into Hrec. revert HForall_fo; intro.
      rewrite Hnparam skipn_0 in HForall_fo. apply Forall_map_inv in HForall_fo.
      eapply Forall_mix in Hrec; try apply HForall_fo.
      eapply Forall_mix in Hrec; try apply H11. clear HForall_fo H11.    
      eapply Forall_impl; eauto. clear Hrec. intros ? [HForall_fo Hrec]. 
      assert (CoqType_to_camlType mind Hparam Hfo = CoqType_to_camlType mind Hparam Hfo_nil).
      { unfold CoqType_to_camlType; f_equal. apply CoqType_to_camlType_fo_irr. }
      rewrite H11; clear H11.
      case_eq (nth_error (ind_bodies mind) (isConstruct_ind a)).
      2: { intro HNone. eapply  nth_error_Some in HNone; eauto. }
      intros Eind' He.  
      eapply realize_adt_value_fo; cbn; eauto.
      eapply HΣ. now rewrite CoqType_to_camlType'_length.
      unfold lookup_inductive, lookup_inductive_gen, lookup_minductive_gen. cbn. 
      rewrite ReflectEq.eqb_refl. now rewrite He.
      apply Hrec; eauto. now destruct Hrec.
      Unshelve. all: eauto.
  Qed.


  Lemma CoqValue_to_CamlValue' {funext : Funext} {P : Pointer} {H : CompatiblePtr P P} (cf := extraction_checker_flags)
  (efl := EInlineProjections.switch_no_params EWellformed.all_env_flags)  {has_rel : EWellformed.has_tRel} {has_box : EWellformed.has_tBox}  
  {HP : @Heap P} `{@CompatibleHeap P P _ _ _} `{WcbvFlags} `{EWellformed.EEnvFlags}
  univ retro univ_decl kn mind
  (Hheap_refl : forall h, R_heap h h)
  (Hparam : ind_params mind = [])
  (Hindices : Forall (fun ind => ind_indices ind = []) (ind_bodies mind))
  (Hnparam : ind_npars mind = 0)
  (Hind : ind_finite mind == Finite )
  (Hmono : ind_universes mind = Monomorphic_ctx)
  (Σ0 := mk_global_env univ [(kn , InductiveDecl mind)] retro)
  (Hgood : pcuic_good_for_extraction Σ0)
  (Hfo_nil : is_true (forallb (@firstorder_oneind [] mind) (ind_bodies mind))) :
  let adt := CoqType_to_camlType mind Hparam Hfo_nil in
  let Σ : global_env_ext_map := (build_global_env_map Σ0, univ_decl) in
  PCUICTyping.wf_ext Σ ->
  with_constructor_as_block = true ->
  forall t ind Eind, 
(*  ind < List.length (snd adt) -> *)
  lookup_inductive Σ (mkInd kn ind) = Some (mind, Eind) ->
  forall (wt : Σ ;;; [] |- t : tInd (mkInd kn ind) [])
  (expΣ : PCUICEtaExpand.expanded_global_env Σ)
  (expt : PCUICEtaExpand.expanded Σ [] t),
  forall h v, R_heap h h ->
    eval [] empty_locals h (compile_pipeline Σ t) h v
    -> realize_ADT _ _ [] [] adt [] All_nil ind v.
  Proof.
    intros ? ? ? ? ? ? ? Hlookup wt ? ? ? ? ? Heval. 
    eapply CoqValue_to_CamlValue in Heval; eauto. rewrite to_list_nth in Heval; eauto.
    unfold lookup_inductive, lookup_inductive_gen, lookup_minductive_gen in Hlookup.
    destruct (lookup_env _ _); [|inversion Hlookup]. destruct g; [inversion Hlookup|].
    eapply nth_error_Some_length; eauto. cbn in Hlookup. 
    case_eq (nth_error (ind_bodies m) ind); [intros ? e | intro e] ; rewrite e in Hlookup; inversion Hlookup; subst. 
    rewrite e. reflexivity.
    Unshelve. all: eauto.  
  Qed. 
    
From Malfunction Require Import CompileCorrect Pipeline. 

Lemma compile_compose {P:Pointer} {H:Heap} {HP : @CompatiblePtr P P} (efl := extraction_env_flags)
  {HH : @CompatibleHeap _ _ _ H H} 
  (Hvrel_refl : forall v, vrel v v)
  (Hheap_refl : forall h, R_heap h h)
  `{WcbvFlags} (cf:=config.extraction_checker_flags) 
  (Σ:global_env_ext_map) h h' t u' u v w na A B :
  ∥ Σ ;;; [] |- t : tProd na A B ∥ ->
  ~ ∥Extract.isErasable Σ [] t∥ -> 
  eval [] empty_locals h (compile_pipeline Σ u) h v ->
  eval [] empty_locals h u' h' v ->
  eval [] empty_locals h (Mapply (compile_pipeline Σ t, [u'])) h' w ->
  ∥{w' & vrel w w' /\ 
        eval [] empty_locals h (compile_pipeline Σ (tApp t u)) h w'}∥.
Proof.
  intros Htyp Herase Hu Hu' Happ.
  erewrite compile_app; eauto.
  inversion Happ; subst. 
  - epose proof (compile_pure _ t).
    eapply isPure_heap in H1 as [Hfpure heq]; eauto.
    2: intros; cbn; eauto. symmetry in heq; subst. pose proof (Hu_copy := Hu).
    eapply isPure_heap in Hu as [Hvpure _]; try eapply compile_pure; intros; cbn in *; eauto.
    eapply eval_det in Hu' as [? ?]; eauto. 3: econstructor.
    2: intros ? ? ? Hempty; inversion Hempty.
    destruct Hfpure as [? Hepure]. eapply isPure_heap_irr with (h'':=h) in H8; eauto.
    2: { intro; cbn. unfold Ident.Map.add. destruct Ident.eqb; eauto. 
         eapply isPure_value_vrel'; eauto. }
    eapply eval_sim with (iglobals := []) in H8 as [[h'' [w' [? [? ?]]]]]; eauto.
    2: { eapply vrel_add; eauto. intro. eauto. }
    sq. exists w'. split; eauto. econstructor 3; eauto. 
    eapply isPure_heap_irr; eauto. 
    { intro; cbn. unfold Ident.Map.add. destruct Ident.eqb; eauto. }
  - epose proof (compile_pure _ t).
    eapply isPure_heap in H1 as [Hfpure heq]; eauto.
    2: intros; cbn; eauto. symmetry in heq; subst. pose proof (Hu_copy := Hu).
    eapply isPure_heap in Hu as [Hvpure _]; try eapply compile_pure; intros; cbn in *; eauto.
    eapply eval_det in Hu' as [? ?]; eauto. 3: econstructor.
    2: intros ? ? ? Hempty; inversion Hempty.
    destruct Hfpure as [? Hepure]. 
    assert (isPure e).
    { rewrite nth_nth_error in H6. 
      eapply (nth_error_forall (n := n)) in Hepure; cbn in *; eauto.
      2: destruct nth_error; inversion H6; subst; eauto.
      eauto. }
    eapply isPure_heap_irr with (h'':=h) in H9; eauto.
    2: { intro; cbn. unfold Ident.Map.add. destruct Ident.eqb; eauto. 
         eapply isPure_value_vrel'; eauto.
         eapply isPure_add_self; eauto. }
    eapply eval_sim with (iglobals := []) in H9 as [[h'' [w' [? [? ?]]]]]; eauto.
    2: { eapply vrel_add; eauto. intro. eauto. }
    sq. exists w'. split; eauto. econstructor 4; eauto. 
    eapply isPure_heap_irr; eauto.
    { intro; cbn. unfold Ident.Map.add. destruct Ident.eqb; eauto.
      eapply isPure_add_self; eauto.
     }
  - erewrite compile_function in H7; eauto. inversion H7.
Qed.  

From MetaCoq.PCUIC Require Import PCUICWellScopedCumulativity. 

Lemma Prod_ind_irred `{checker_flags} Σ Γ f na kn ind ind' X :
  let PiType := tProd na (tInd (mkInd kn ind) []) (tInd (mkInd kn ind') []) in
  wf_ext Σ ->
  Σ ;;; Γ |- f : PiType ->
  Σ ;;; Γ ⊢ PiType ⇝ X ->
  PiType = X.
Proof.
  intros ? ? Hf Hred. 
  eapply PCUICConversion.invert_red_prod in Hred as [A' [B' [? [? ?]]]]; subst.
  unfold PiType. f_equal. 
  - eapply PCUICReduction.red_rect'; eauto. intros; subst.
    eapply PCUICNormal.red1_mkApps_tInd_inv with (v:=[]) in X1 as [? [? ?]]; subst.
    inversion o.
  - eapply PCUICReduction.red_rect'; eauto. 2: eapply c. intros; subst.
    eapply PCUICNormal.red1_mkApps_tInd_inv with (v:=[]) in X1 as [? [? ?]]; subst.
    inversion o.
Qed. 

Lemma Prod_ind_principal `{checker_flags} Σ Γ f na kn ind ind' :
  let PiType := tProd na (tInd (mkInd kn ind) []) (tInd (mkInd kn ind') []) in
  wf_ext Σ ->
  Σ ;;; Γ |- f : PiType ->
  forall B, Σ ;;; Γ |- f : B -> Σ ;;; Γ ⊢ PiType ≤ B.
Proof. 
  intros ? ? Hf B HB.
  pose proof (HB' := HB); eapply PCUICPrincipality.principal_type in HB as [Pf Hprinc]; eauto.
  pose proof (Hprinc' := Hprinc); specialize (Hprinc _ Hf) as [? ?].
  assert (Σ ;;; Γ ⊢ Pf = PiType).
  { 
    eapply ws_cumul_pb_alt_closed in w as [? [? [[? ?] ?]]].
    eapply Prod_ind_irred in c; eauto.
    subst.
    eapply ws_cumul_pb_alt_closed. exists x; exists PiType. repeat split; eauto.
    inversion c0; subst; clear c0; econstructor; eauto.
    inversion X1; subst; clear X1; econstructor; eauto. 
    unfold PCUICEquality.R_global_instance_gen, PCUICEquality.R_opt_variance in *. cbn in *.
    destruct lookup_inductive_gen; eauto. destruct p. destruct destArity; eauto.
    destruct p. destruct context_assumptions; eauto. cbn in *. destruct ind_variance; eauto.
    induction u; try econstructor; eauto. 
    }
  specialize (Hprinc' _ HB') as [? ?].
  etransitivity; eauto. eapply PCUICContextConversion.ws_cumul_pb_eq_le; symmetry; eauto.
Qed.  

Lemma interoperability_firstorder_function {funext:Funext} {P:Pointer} {H:Heap} {HP : @CompatiblePtr P P}
  {HH : @CompatibleHeap _ _ _ H H} 
  (Hvrel_refl : forall v, vrel v v)
  (Hheap_refl : forall h, R_heap h h) `{WcbvFlags} (efl := extraction_env_flags) (cf:=config.extraction_checker_flags)
    univ retro univ_decl kn mind 
  (Hparam : ind_params mind = [])
  (Hindices : Forall (fun ind => ind_indices ind = []) (ind_bodies mind))
  (Hnparam : ind_npars mind = 0)
  (Hfinite : ind_finite mind == Finite)
  (Hmono : ind_universes mind = Monomorphic_ctx)
  (Σ0 := mk_global_env univ [(kn , InductiveDecl mind)] retro)
  (Hgood : pcuic_good_for_extraction Σ0)
  (Hfo : is_true (forallb (@firstorder_oneind [] mind) (ind_bodies mind))) ind ind' Eind Eind' f na l:
  let adt := CoqType_to_camlType mind Hparam Hfo in
  let Σ : global_env_ext_map := (build_global_env_map Σ0, univ_decl) in
  let global_adt := add_ADT _ _ [] [] kn adt in 
  pcuic_good_for_extraction Σ ->
  ind_sort Eind = Universe.lType l ->
  ind_sort Eind' = Universe.lType l ->
  PCUICTyping.wf_ext (Σ,univ_decl) ->
  PCUICEtaExpand.expanded_global_env Σ ->
  PCUICEtaExpand.expanded Σ [] f ->
  with_constructor_as_block = true ->
  ind < List.length (snd adt) ->
  ind' < List.length (snd adt) ->
  lookup_inductive Σ (mkInd kn ind) = Some (mind, Eind) ->
  lookup_inductive Σ (mkInd kn ind') = Some (mind, Eind') ->
  ∥ Σ ;;; [] |- f : tProd na (tInd (mkInd kn ind) []) (tInd (mkInd kn ind') []) ∥ ->
  realize_term _ _ [] []
        global_adt (Arrow (Adt kn ind []) (Adt kn ind' [])) 
        (compile_pipeline Σ f).
Proof.
  intros ? ? ? Hextract ? Hind_sort wfΣ expΣ expf ? ? ? Hlookup Hlookup'. intros. simpl. rewrite ReflectEq.eqb_refl.
  unfold to_realize_term. cbn. 
  pose proof (wfΣ_ext := wfΣ). destruct wfΣ as [wfΣ ?].
  intros t Ht. unfold to_realize_term in *. intros h h' v Heval.
  pose proof (Hlookup'' := Hlookup).
  pose proof (Hlookup''' := Hlookup').
  unfold lookup_inductive, lookup_inductive_gen, lookup_minductive_gen in Hlookup, Hlookup'. cbn in Hlookup, Hlookup'.
  rewrite ReflectEq.eqb_refl in Hlookup, Hlookup'.
  assert (HEind : nth_error (ind_bodies mind) ind = Some Eind).
  { destruct (nth_error (ind_bodies mind) ind); now inversion Hlookup. }
  assert (Htype_ind : (Σ, univ_decl);;; []
  |- tInd {| inductive_mind := kn; inductive_ind := ind |}
       [] : (tSort (ind_sort Eind))@[[]]).
  {  unshelve epose proof (type_Ind (Σ,univ_decl) [] (mkInd kn ind) [] mind Eind _ _ _).
  *** econstructor.
  *** unfold declared_constructor, declared_inductive. subst. now cbn.
  *** unfold consistent_instance_ext, consistent_instance; cbn.
     now rewrite Hmono.
  *** unfold ind_type in X. destruct Eind; cbn in *.
      unfold PCUICTyping.wf in wfΣ. inversion wfΣ as [_ wfΣ'].
      cbn in wfΣ'. inversion wfΣ'. clear X0. inversion X1. inversion on_global_decl_d.
      eapply Alli_nth_error in onInductives; eauto. cbn in onInductives.
      inversion onInductives. cbn in *.
      eapply nth_error_forall in Hindices; eauto. cbn in Hindices. rewrite Hindices in ind_arity_eq.                       
      cbn in ind_arity_eq. rewrite Hparam in ind_arity_eq. cbn in ind_arity_eq.
      now rewrite ind_arity_eq in X. }
  assert (HEind' : nth_error (ind_bodies mind) ind' = Some Eind').
  { destruct (nth_error (ind_bodies mind) ind'); now inversion Hlookup'. }
  assert (Htype_ind' : (Σ, univ_decl);;; []
  |- tInd {| inductive_mind := kn; inductive_ind := ind' |}
        [] : (tSort (ind_sort Eind'))@[[]]).
  {  unshelve epose proof (type_Ind (Σ,univ_decl) [] (mkInd kn ind') [] mind Eind' _ _ _).
  *** econstructor.
  *** unfold declared_constructor, declared_inductive. subst. now cbn.
  *** unfold consistent_instance_ext, consistent_instance; cbn.
      now rewrite Hmono.
  *** unfold ind_type in X. destruct Eind'; cbn in *.
      unfold PCUICTyping.wf in wfΣ. inversion wfΣ as [_ wfΣ'].
      cbn in wfΣ'. inversion wfΣ'. clear X0. inversion X1. inversion on_global_decl_d.
      eapply Alli_nth_error in onInductives; eauto. cbn in onInductives.
      inversion onInductives. cbn in *.
      eapply nth_error_forall in Hindices; eauto. cbn in Hindices. rewrite Hindices in ind_arity_eq.                       
      cbn in ind_arity_eq. rewrite Hparam in ind_arity_eq. cbn in ind_arity_eq.
      now rewrite ind_arity_eq in X. } 
  assert (Htype_ind'' : (Σ, univ_decl);;;
  [],,
  vass na
    (tInd {| inductive_mind := kn; inductive_ind := ind |}
       [])
  |- tInd {| inductive_mind := kn; inductive_ind := ind' |}
       [] : tSort (subst_instance_univ [] (ind_sort Eind'))).
  { eapply (PCUICWeakeningTyp.weakening  _ _ ([vass na (tInd {| inductive_mind := kn; inductive_ind := ind |} [])])) in Htype_ind'; cbn in Htype_ind'; eauto.
    repeat constructor. cbn. now eexists. }
  assert (Herase: ~ ∥ Extract.isErasable (Σ, univ_decl) [] f ∥).
  { sq. eapply EArities.not_isErasable with (u := subst_instance_univ [] (Universe.lType l)); eauto; intros. 
    - sq. eapply Prod_ind_irred ; eauto.
    - sq. eapply Prod_ind_principal; eauto. 
    - intro; sq; eauto.
    - sq. rewrite <- (sort_of_product_idem (subst_instance_univ [] (Universe.lType l))). eapply type_Prod; eauto.
      now rewrite -H1. now rewrite -Hind_sort. }
  inversion Heval; subst.
  - specialize (Ht _ _ _ H10).
    unshelve eapply camlValue_to_CoqValue in Ht. 15:eauto. all:eauto; cbn.
    destruct Ht as [t_coq [? [Ht_typ Ht_eval]]]. specialize (Ht_eval h2). 
    eapply isPure_heap in H8; try eapply compile_pure; intros; cbn; eauto. cbn in H8.
    destruct H8 as [[? ? ] ?]. eapply isPure_heap in H13 as [? ?]; eauto.
    2: { unfold Ident.Map.add; intro. destruct (Ident.eqb s x); eauto.
      eapply isPure_heap in Ht_eval; try eapply compile_pure; intros; cbn; eauto. now destruct Ht_eval. } 
    subst. eapply compile_compose in H10 as [[? [? ?]]]; eauto.
    2: { eapply isPure_heap_irr,  Ht_eval; try eapply compile_pure; intros; cbn; eauto. }
    assert (v = x0). { unshelve eapply isPure_value_vrel_eq; eauto. }
    subst. sq. unfold adt. eapply CoqValue_to_CamlValue' with (t := tApp f t_coq). all:eauto.
    unshelve epose proof (type_App _ _ _ _ _ _ _ _ _ H5 Ht_typ); try exact (subst_insatance_univ [] (ind_sort Eind)); eauto.
    eapply PCUICEtaExpand.expanded_tApp; eauto.
  - specialize (Ht _ _ _ H9).
    eapply camlValue_to_CoqValue in Ht. 10:eauto. all: eauto; cbn.
    destruct Ht as [t_coq [Hexpand_t [Ht_typ Ht_eval]]]. specialize (Ht_eval h2).
    eapply isPure_heap in H8; try eapply compile_pure; intros; cbn; eauto.
    cbn in H8. destruct H8 as [[? ? ] ?]. rewrite nth_nth_error in H11. 
    case_eq (nth_error mfix n); intros;  [|rewrite H10 in H11; inversion H11].
    pose proof (H5_copy := H7). eapply (nth_error_forall (n:=n)) in H7; eauto.
    rewrite H10 in H11. subst. 
    eapply isPure_heap in H14 as [? ?]; eauto.
    2: { unfold Ident.Map.add; intro; destruct (Ident.eqb s y); eauto.
         eapply isPure_heap in Ht_eval; try eapply compile_pure; intros; cbn; eauto. 
         now destruct Ht_eval as [? _]. eapply isPure_add_self; eauto. }
    cbn in H7. subst. eapply compile_compose in H9 as [[? [? ?]]]; eauto.
    2: { eapply isPure_heap_irr,  Ht_eval; try eapply compile_pure; intros; cbn; eauto. }
    assert (v = x). { unshelve eapply isPure_value_vrel_eq; eauto. }
    subst. sq. unshelve eapply CoqValue_to_CamlValue'; try exact H11; eauto.
    sq. unshelve epose proof (type_App _ _ _ _ _ _ _ _ _ H5 Ht_typ); try exact (subst_instance_univ [] (ind_sort Eind)); eauto. 
    rewrite <- (sort_of_product_idem _). rewrite {2}H1 -Hind_sort.
    eapply type_Prod; eauto.
    eapply PCUICEtaExpand.expanded_tApp; eauto. 
  - rewrite (compile_function _ _ _ _ _ _ _ _ H5 _ H9) in H12; eauto. inversion H12.
  Unshelve. all: eauto.
Qed.
