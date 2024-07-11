From Malfunction Require Import FFI.
From VerifiedExtraction Require Import Extraction.
From MetaCoq.Utils Require Import bytestring MCString.
Local Open Scope bs. (* bytestrings *)

(* Set Verified Extraction Build Directory "_build".
 *)
Definition test (x : unit) := coq_msg_info "Hello world!".

(* Set Debug "verified-extraction". *)
Set Warnings "-primitive-turned-into-axiom".

From Coq Require Import PrimFloat.
Definition test_float : float := abs (1000%float).
Verified Extraction -typed -unsafe -time -fmt -compile-plugin -load test_float.

Verified Extraction -typed -unsafe -time -fmt -compile-plugin -run (abs 1.5%float).

(* Pure running time of the compiled code *)
(* Time MetaCoq Eval test_float.
Time MetaCoq Eval test_float.
 *)