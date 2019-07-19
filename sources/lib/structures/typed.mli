(******************************************************************************)
(*                                                                            *)
(*     The Alt-Ergo theorem prover                                            *)
(*     Copyright (C) 2006-2013                                                *)
(*                                                                            *)
(*     Sylvain Conchon                                                        *)
(*     Evelyne Contejean                                                      *)
(*                                                                            *)
(*     Francois Bobot                                                         *)
(*     Mohamed Iguernelala                                                    *)
(*     Stephane Lescuyer                                                      *)
(*     Alain Mebsout                                                          *)
(*                                                                            *)
(*     CNRS - INRIA - Universite Paris Sud                                    *)
(*                                                                            *)
(*     This file is distributed under the terms of the Apache Software        *)
(*     License version 2.0                                                    *)
(*                                                                            *)
(*  ------------------------------------------------------------------------  *)
(*                                                                            *)
(*     Alt-Ergo: The SMT Solver For Software Verification                     *)
(*     Copyright (C) 2013-2018 --- OCamlPro SAS                               *)
(*                                                                            *)
(*     This file is distributed under the terms of the Apache Software        *)
(*     License version 2.0                                                    *)
(*                                                                            *)
(******************************************************************************)

(** Typed AST

    This module defines a typed AST, used to represent typed terms
    before they are hashconsed. *)


(** {2 Annotations} *)

type ('a, 'b) annoted = {
  c : 'a;
  annot : 'b;
}
(** An annoted structure. Usually used to annotate terms. *)

val new_id : unit -> int
(** Generate a new, fresh integer (useful for annotations). *)

val mk : ?annot:int -> 'a -> ('a, int) annoted
(** Create an annoted value with the given annotation.
    If no annotation is given, a fresh annotation is generated
    using {!new_id}. *)


(** {2 Terms and formulas} *)


type tconstant =
  (* TODO: make Tint hold an arbitrary precision integer ? *)
  | Tint of string      (** An integer constant. *)
  | Treal of Num.num    (** Real constant. *)
  | Tbitv of string     (** Bitvector constant. *)
  | Ttrue               (** The true boolean (or proposition ?) *)
  | Tfalse              (** The false boolean *)
  | Tvoid               (** The only value of type unit *)
(** Typed constants. *)

type oplogic =
  | OPand       (** conjunction *)
  | OPor        (** disjunction *)
  | OPxor       (** exclusive disjunction *)
  | OPimp       (** implication *)
  | OPnot       (** negation *)
  | OPiff       (** equivalence *)
  | OPif        (** conditional branching *)
(** Logic operators. *)

type pattern =
  | Constr of { name : Hstring.t ; args : (Var.t * Hstring.t * Ty.t) list}
  | Var of Var.t


type 'a tterm = {
  tt_ty : Ty.t;         (** type of the term *)
  tt_desc : 'a tt_desc; (** term descriptor *)
}
(** Typed terms. Polymorphic in the annotation:
    an ['a tterm] is a term annoted with values of type ['a]. *)

and 'a atterm = ('a tterm, 'a) annoted
(** type alias for annoted typed terms. *)

and 'a tt_desc =
  | TTconst of tconstant
  (** Term constant *)
  | TTvar of Symbols.t
  (** Term variables *)
  | TTinfix of 'a atterm * Symbols.t * 'a atterm
  (** Infix symbol application *)
  | TTprefix of Symbols.t * 'a atterm
  (** Prefix symbol application *)
  | TTapp of Symbols.t * 'a atterm list
  (** Arbitrary symbol application *)
  | TTmapsTo of Var.t * 'a atterm
  (** Used in semantic triggers for floating point arithmetic.
      See sources/preludes/fpa-theory-2017-01-04-16h00.why *)
  | TTinInterval of 'a atterm * Symbols.bound * Symbols.bound
  (** Represent floating point intervals (used for triggers in Floating
      point arithmetic theory).
      [TTinInterval (t, lower, upper)] is a constraint
      stating that term [t] is between its lower and upper bound. *)
  | TTget of 'a atterm * 'a atterm
  (** Get operation on arrays *)
  | TTset of 'a atterm * 'a atterm * 'a atterm
  (** Set operation on arrays *)
  | TTextract of 'a atterm * 'a atterm * 'a atterm
  (** Extract a sub-bitvector *)
  | TTconcat of 'a atterm * 'a atterm
  (* Concatenation of bitvectors *)
  | TTdot of 'a atterm * Hstring.t
  (** Field access on structs/records *)
  | TTrecord of (Hstring.t * 'a atterm) list
  (** Record creation. *)
  | TTlet of (Symbols.t * 'a atterm) list * 'a atterm
  (** Let-bindings. Accept a list of sequential let-bindings. *)
  | TTnamed of Hstring.t * 'a atterm
  (** Attach a label to a term. *)
  | TTite of 'a atform * 'a atterm * 'a atterm
  (** Conditional branching, of the form
      [TTite (condition, then_branch, else_branch)]. *)

  | TTproject of bool * 'a atterm  * Hstring.t
  (** Field (conditional) access on ADTs. The boolean is true when the
      projection is 'guarded' and cannot be simplified (because
      functions are total) *)

  | TTmatch of 'a atterm * (pattern * 'a atterm) list
  (** pattern matching on ADTs *)

  | TTform of 'a atform
  (** formulas inside terms: simple way to add them without making a
      lot of changes *)
(** Typed terms descriptors. *)
(* TODO: replace tuples by records (possible inline records to
         avoid polluting the namespace ?) with explicit field names. *)


and 'a atatom = ('a tatom, 'a) annoted
(** Type alias for annoted typed atoms. *)

and 'a tatom =
  | TAtrue
  (** The [true] atom *)
  | TAfalse
  (** The [false] atom *)
  | TAeq of 'a atterm list
  (** Equality of a set of typed terms. *)
  | TAdistinct of 'a atterm list
  (** Disequality. All terms in the set are pairwise distinct. *)
  | TAneq of 'a atterm list
  (** Equality negation: at least two elements in the list
      are not equal. *)
  | TAle of 'a atterm list
  (** Arithmetic ordering: lesser or equal. Chained on lists of terms. *)
  | TAlt of 'a atterm list
  (** Strict arithmetic ordering: less than. Chained on lists of terms. *)
  | TApred of 'a atterm * bool
  (** Term predicate, negated if the boolean is true.
      [TApred (t, negated)] is satisfied iff [t <=> not negated] *)

  | TTisConstr of ('a tterm, 'a) annoted  * Hstring.t
  (** Test if the given term's head symbol is identitical to the
      provided ADT consturctor *)


(** Typed atoms. *)

and 'a quant_form = {
  qf_bvars : (Symbols.t * Ty.t) list;
  (** Variables that are quantified by this formula. *)
  qf_upvars : (Symbols.t * Ty.t) list;
  (** Free variables that occur in the formula. *)
  qf_triggers : ('a atterm list * bool) list;
  (** Triggers associated wiht the formula.
      For each trigger, the boolean specifies whether the trigger
      was given in the input file (compared to inferred). *)
  qf_hyp : 'a atform list;
  (** Hypotheses of axioms with semantic triggers in FPA theory. Typically,
      these hypotheses reduce to TRUE after instantiation *)
  qf_form : 'a atform;
  (** The quantified formula. *)
}
(** Quantified formulas. *)

and 'a atform = ('a tform, 'a) annoted
(** Type alias for typed annoted formulas. *)

and 'a tform =
  | TFatom of 'a atatom
  (** Atomic formula. *)
  | TFop of oplogic * 'a atform list
  (** Application of logical operators. *)
  | TFforall of 'a quant_form
  (** Universal quantification. *)
  | TFexists of 'a quant_form
  (** Existencial quantification. *)
  | TFlet of (Symbols.t * Ty.t) list *
             (Symbols.t * 'a tlet_kind) list *
             'a atform
  (** Let binding. [TFlet (fv, bv, body)] represents the binding
      of the variables in [bv] (to the corresponding term or formula),
      in the formula [body]. The list [fv] contains the list of free term
      variables (together with their type) that occurs in the formula. *)
  | TFnamed of Hstring.t * 'a atform
  (** Attach a name to a formula. *)

  | TFmatch of 'a atterm * (pattern * 'a atform) list
  (** pattern matching on ADTs *)

(** Typed formulas. *)

and 'a tlet_kind =
  | TletTerm of 'a atterm   (** Term let-binding *)
  | TletForm of 'a atform   (** Formula let-binding *)
(** The different kinds of let-bindings,
    whether they bind terms or formulas. *)


(** {2 Declarations} *)


type 'a rwt_rule = {
  rwt_vars : (Symbols.t * Ty.t) list; (** Variables of the rewrite rule *)
  rwt_left : 'a;          (** Left side of the rewrite rule (aka pattern). *)
  rwt_right : 'a;         (** Right side of the rewrite rule. *)
}
(** Rewrite rules.
    Polymorphic to allow for different representation of terms. *)


type goal_sort =
  | Cut
  (** Introduce a cut in a goal. Once the cut proved,
      it's added as a hypothesis. *)
  | Check
  (** Check if some intermediate assertion is prouvable *)
  | Thm
  (** The goal to be proved *)
(** Goal sort. Used in typed declarations. *)

val fresh_hypothesis_name : goal_sort -> string
(** create a fresh hypothesis name given a goal sort. *)

val is_local_hyp : string -> bool
(** Assuming a name generated by {!fresh_hypothesis_name},
    answers whether the name design a local hypothesis ? *)

val is_global_hyp : string -> bool
(** Assuming a name generated by {!fresh_hypothesis_name},
    does the name design a global hypothesis ? *)


type tlogic_type =
  | TPredicate of Ty.t list       (** Predicate type declarations *)
  | TFunction of Ty.t list * Ty.t (** Function type declarations *)
(** Type declarations. Specifies the list of argument types,
    as well as the return type for functions (predicate implicitly
    returns a proposition, so there is no need for an explicit return
    type). *)

type 'a atdecl = ('a tdecl, 'a) annoted
(** Type alias for annoted typed declarations. *)

and 'a tdecl =
  | TTheory of Loc.t * string * Util.theories_extensions * 'a atdecl list
  (** Theory declarations. The list of declarations in a Theory may
      only contain Axioms. *)
  | TAxiom of Loc.t * string * Util.axiom_kind * 'a atform
  (** New axiom that can be used in proofs. *)
  | TRewriting of Loc.t * string * ('a atterm rwt_rule) list
  (** New rewrite rule that can be used. *)
  | TNegated_goal of Loc.t * goal_sort * string * 'a atform
  (** New goal to prove, already negated !
      WARNING: the formula given is added as an axiom,
               so be sure to negate it before creating
               a goal of this form. *)
  | TLogic of Loc.t * string list * tlogic_type
  (** Function (or predicate) type declaration. *)
  | TPredicate_def of
      Loc.t * string * (string * Ty.t) list * 'a atform
  (** Predicate definition.
      [TPredicate_def (loc, name, vars, body)] defines a predicate
      [fun vars => body]. *)
  | TFunction_def of
      Loc.t * string *
      (string * Ty.t) list * Ty.t * 'a atform
  (** Predicate definition.
      [TPredicate_def (loc, name, vars, ret, body)] defines a function
      [fun vars => body], where body has type [ret]. *)
  | TTypeDecl of Loc.t * Ty.t
  (** New type declaration. [TTypeDecl (loc, vars, t, body)]
      declares a type [t], with parameters [vars], and with
      contents [body]. This new type may either be abstract,
      a record type, or an enumeration. *)
(** Typed declarations. *)
(* TODO: wrap this in a record to factorize away
   the location and name of the declaration ? *)


(** {5 Monomorphization} *)

val monomorphize_term : 'a atterm -> 'a atterm
val monomorphize_atom : 'a atatom -> 'a atatom
val monomorphize_form : 'a atform -> 'a atform
(** Monomorphization functions on expressions. *)


(** {5 Printing} *)

val print_term : Format.formatter -> _ atterm -> unit
(** Print annoted typed terms. Ignore the annotations. *)

val print_formula : Format.formatter -> _ atform -> unit
(**Print annoted typed formulas; Ignores the annotations. *)

val print_binders : Format.formatter -> (Symbols.t * Ty.t) list -> unit
(** Print a list of bound typed variables. *)

val print_triggers : Format.formatter -> ('a atterm list * bool) list -> unit
(** Print a list of triggers. *)

val print_goal_sort : Format.formatter -> goal_sort -> unit
(** Print a goal sort *)

val print_rwt :
  (Format.formatter -> 'a -> unit) ->
  Format.formatter -> 'a rwt_rule -> unit
(** Print a rewrite rule *)


(** {2 Expressions} *)

module Safe : sig

  type t =
    | Term of int atterm  (** Terms *)
    | Atom of int atatom  (** Atoms *)
    | Form of int atform * Ty.tvar list
    (** Formulas additionally carry their set of explicitly quantified
        type variables, in order to disallow deep type quantification. *)
  (** An expression is either a term, an atom, or a formula. *)

  val print : Format.formatter -> t -> unit
  (** Printer function. *)

  val ty : t -> Ty.t
  (** Return the type of the given expression. *)

  module Var : sig

    type t
    (** Typed variables *)

    val hash : t -> int
    (** hash function *)

    val equal : t -> t -> bool
    (** equality funciton *)

    val compare : t -> t -> int
    (** comparison function *)

    val print : Format.formatter -> t -> unit
    (** Printer function *)

    val mk : string -> Ty.t -> t
    (** Create a typed variable from a name and type. *)

    val make : Symbols.t -> Ty.t -> t
    (** Create a typed variable from a symbol and type. *)

    val ty : t -> Ty.t
    (** Return the type of a typed variable. *)

  end

  module Const : sig

    type t
    (** Typed function symbols (aka constants) *)

    val hash : t -> int
    (** hash function *)

    val equal : t -> t -> bool
    (** equality funciton *)

    val compare : t -> t -> int
    (** comparison function *)

    val print : Format.formatter -> t -> unit
    (** Printer function *)

    val print_ty :
      Format.formatter ->
      (Ty.Safe.Var.t list * Ty.t list * Ty.t) -> unit
    (** Print a term constant's type. *)

    val print_full : Format.formatter -> t -> unit
    (** Print a constant together with its type. *)

    val arity : t -> int * int
    (** Return the expected number of arguments of the constants.
        The pair contains first the number of expected type
        arguments (for polymorphic functions), and then the number
        of reguler (or term) arguments. *)

    val mk : string -> Ty.tvar list -> Ty.t list -> Ty.t -> t
    (** Create a typed funciton symbol. Takes as arguments the
        symbol of the function, the type variables that occur in its
        type, the list of argument's expected types, and the function
        return type. *)

    val tag : t -> _ -> _ -> unit
    (** Noop, there for compatibility with Dolmen's interface. *)

    val name : t -> string
    (** Name of the constant. *)

    val tlogic_type : t -> tlogic_type
    (** Generate the logic type of the constant symbol. *)

    val _true : t
    (** The [true] constant *)

    val _false : t
    (** The [false] constant *)

  end

  (** {5 Typing exceptions} *)

  exception Deep_type_quantification
  (** Alt-ergo restricts type variables to be quantified at the
      top of formulas. This exception is raised when trying to
      build a formula that contain a formula with explicitly
      quantified type variables. *)

  exception Wrong_type of t * Ty.t
  (** [Wrong_type (t, ety)] is raised by function that checks
      and compute the type of expressions, when an expression
      was expected to have type [ety], but doe snot have that
      type (as returned by the {! ty} function). *)

  exception Wrong_arity of Const.t * int * int
  (** [Wrong_arity (c, n, m)] is raised when a constant [c]
      is applied to [n] number of type arguments and [m] term
      arguments, but these number do not match the arity of [c],
      as defined by {! Const.arity}. *)


  (** {3 Expression inspection} *)

  val expect_prop : t -> Ty.Safe.Var.t list * int atform
  (** Unwrap a formula from an expression. *)

  (** {3 Expression building} *)

  val of_var : Var.t -> t
  (** Create an expression out of a variable. *)

  val apply : Const.t -> Ty.t list -> t list -> t
  (** Apply the given typed funciton symbol to the list of
      types and terms given. Automatically checks that the arguments
      have the correct type, and computes the type of the resulting
      expression.
      @raise Wrong_arity
      @raise Wrong_type
  *)

  val _true : t
  (** The [true] expression *)

  val _false : t
  (** The [false] expression *)

  val eq : t -> t -> t
  (** Create an equality between two expressions.
      @raise Wrong_type
  *)

  val eqs : t list -> t
  (** Create a chain of equalities.
      @raise Wrong_type
  *)

  val distinct : t list -> t
  (** Create a distinct expression.
      @raise Wrong_type
  *)

  val neg : t -> t
  (** Propositional negation
      @raise Wrong_type
      @raise Deep_type_quantification
  *)

  val imply : t -> t -> t
  (** Propositional implication
      @raise Wrong_type
      @raise Deep_type_quantification
  *)

  val equiv : t -> t -> t
  (** Propositional equivalence
      @raise Wrong_type
      @raise Deep_type_quantification
  *)

  val xor : t -> t -> t
  (** Propositional exclusive disjunction
      @raise Wrong_type
      @raise Deep_type_quantification
  *)

  val _and : t list -> t
  (** Propositional conjunction
      @raise Wrong_type
      @raise Deep_type_quantification
  *)

  val _or : t list -> t
  (** Propositional disjunction
      @raise Wrong_type
      @raise Deep_type_quantification
  *)

  val fv : t -> Ty.tvar list * Var.t list
  (** Return the list of free variables that occur in a given term *)

  val all :
    (Ty.tvar list * Var.t list) ->
    (Ty.tvar list * Var.t list) ->
    t -> t
  (** Universal quantification. Accepts as first pair the lists
      of free variables that occur in the resulting formula, then
      the lists of variables quantified in the formula, and then the body
      of the quantified formula.
      @raise Wrong_type
      @raise Deep_type_quantification
  *)

  val ex :
    (Ty.tvar list * Var.t list) ->
    (Ty.tvar list * Var.t list) ->
    t -> t
  (** Existencial quantification. Accepts as first pair the lists
      of free variables that occur in the resulting formula, then
      the lists of variables quantified in the formula, and then the body
      of the quantified formula.
      @raise Wrong_type
      @raise Deep_type_quantification
  *)

  val letin : (Var.t * t) list -> t -> t
  (** Let-binding.
      @raise Wrong_type
      @raise Deep_type_quantification
  *)

  val ite : t -> t -> t -> t
  (** Create a conditional. *)

  val select : t -> t -> t
  (** Create a get operation on functionnal arrays *)

  val store : t -> t -> t -> t
  (** Create a set operation on functionnal arrays. *)

  val mk_bitv : string -> t
  (** Create a bitvector litteral from a string representation.
      The string should only contain characters '0' or '1'. *)

  val bitv_concat : t -> t -> t
  (** Bitvector concatenation. *)

  val bitv_extract : int -> int -> t -> t
  (** Bitvector extraction, using the start and end position
      of the bitvector to extract. *)

  val bitv_repeat : int -> t -> t
  (** Repetition of a bitvector. *)

  val zero_extend : int -> t -> t
  (** Extend the given bitvector with the given numer of 0. *)

  val sign_extend : int -> t -> t
  (** Extend the given bitvector with its most significant bit
      repeated the given number of times. *)

  val rotate_right : int -> t -> t
  (** [rotate_right i x] means rotate bits of x to the right i times. *)

  val rotate_left : int -> t -> t
  (** [rotate_left i x] means rotate bits of x to the left i times. *)

  val bvnot : t -> t
  (** Bitwise negation. *)

  val bvand : t -> t -> t
  (** Bitwise conjunction. *)

  val bvor : t -> t -> t
  (** Bitwise disjunction. *)

  val bvnand : t -> t -> t
  (** [bvnand s t] abbreviates [bvnot (bvand s t)]. *)

  val bvnor : t -> t -> t
  (** [bvnor s t] abbreviates [bvnot (bvor s t)]. *)

  val bvxor : t -> t -> t
  (** [bvxor s t] abbreviates [bvor (bvand s (bvnot t)) (bvand (bvnot s) t)]. *)

  val bvxnor : t -> t -> t
  (** [bvxnor s t] abbreviates
      [bvor (bvand s t) (bvand (bvnot s) (bvnot t))]. *)

  val bvcomp : t -> t -> t
  (** Bitwise comparison. [bvcomp s t] equald [#b1] iff [s] and [t]
      are bitwise equal. *)


  val bvneg : t -> t
  (** Arithmetic complement on bitvectors.
      Supposing an input bitvector of size [m] representing
      an integer [k], the resulting term should represent
      the integer [2^m - k]. *)

  val bvadd : t -> t -> t
  (** Arithmetic addition on bitvectors, modulo the size of
      the bitvectors (overflows wrap around [2^m] where [m]
      is the size of the two input bitvectors). *)

  val bvsub : t -> t -> t
  (** Arithmetic substraction on bitvectors, modulo the size
      of the bitvectors (2's complement subtraction modulo).
      [bvsub s t] should be equal to [bvadd s (bvneg t)]. *)

  val bvmul : t -> t -> t
  (** Arithmetic multiplication on bitvectors, modulo the size
      of the bitvectors (see {!bvadd}). *)

  val bvudiv : t -> t -> t
  (** Arithmetic euclidian integer division on bitvectors. *)

  val bvurem : t -> t -> t
  (** Arithmetic euclidian integer remainder on bitvectors. *)

  val bvsdiv : t -> t -> t
  (** Arithmetic 2's complement signed division.
      (see smtlib's specification for more information). *)

  val bvsrem : t -> t -> t
  (** Arithmetic 2's coplement signed remainder (sign follows dividend).
      (see smtlib's specification for more information). *)

  val bvsmod : t -> t -> t
  (** Arithmetic 2's coplement signed remainder (sign follows divisor).
      (see smtlib's specification for more information). *)

  val bvshl : t -> t -> t
  (** Logical shift left. [bvshl t k] return the result of
      shifting [t] to the left [k] times. In other words,
      this should return the bitvector representing
      [t * 2^k] (since bitvectors represent integers using
      the least significatn bit in cell 0). *)

  val bvlshr : t -> t -> t
  (** Logical shift right. [bvlshr t k] return the result of
      shifting [t] to the right [k] times. In other words,
      this should return the bitvector representing
      [t / (2^k)]. *)

  val bvashr : t -> t -> t
  (** Arithmetic shift right, like logical shift right except that the most
      significant bits of the result always copy the most significant
      bit of the first argument*)

  val bvult : t -> t -> t
  (** Boolean arithmetic comparison (less than).
      [bvult s t] should return the [true] term iff [s < t]. *)

  val bvule : t -> t -> t
  (** Boolean arithmetic comparison (less or equal than). *)

  val bvugt : t -> t -> t
  (** Boolean arithmetic comparison (greater than). *)

  val bvuge : t -> t -> t
  (** Boolean arithmetic comparison (greater or equal than). *)

  val bvslt : t -> t -> t
  (** Boolean signed arithmetic comparison (less than).
      (See smtlib's specification for more information) *)

  val bvsle : t -> t -> t
  (** Boolean signed arithmetic comparison (less or equal than). *)

  val bvsgt : t -> t -> t
  (** Boolean signed arithmetic comparison (greater than). *)

  val bvsge : t -> t -> t
  (** Boolean signed arithmetic comparison (greater or equal than). *)

  val tag : t -> _ -> _ -> unit
  (** Noop, there for compatibility with Dolmen's interface. *)

  module Int : sig
    type nonrec t = t
    (** The type of terms. *)

    val int : string -> t
    (** Build an integer constant. The integer is passed
          as a string, and not an [int], to avoid overflow caused
          by the limited precision of native intgers. *)

    val neg : t -> t
    (** Arithmetic negation. *)

    val add : t -> t -> t
    (** Arithmetic addition. *)

    val sub : t -> t -> t
    (** Arithmetic substraction *)

    val mul : t -> t -> t
    (** Arithmetic multiplication *)

    val div : t -> t -> t
    (** Integer division. See Smtlib theory for a full description. *)

    val modulo : t -> t -> t
    (** Integer remainder See Smtlib theory for a full description. *)

    val abs : t -> t
    (** Arithmetic absolute value. *)

    val lt : t -> t -> t
    (** Arithmetic "less than" comparison. *)

    val le : t -> t -> t
    (** Arithmetic "less or equal" comparison. *)

    val gt : t -> t -> t
    (** Arithmetic "greater than" comparison. *)

    val ge : t -> t -> t
    (** Arithmetic "greater or equal" comparison. *)

    val divisible : string -> t -> t
    (** Arithmetic divisibility predicate. Indexed over
        constant integers (represented as strings, see {!int}). *)
  end

  module Real : sig
    type nonrec t = t
    (** The type of terms. *)

    val real : string -> t
    (** Build a real constant. The string should respect
        smtlib's syntax for INTEGER or DECIMAL. *)

    val neg : t -> t
    (** Arithmetic negation. *)

    val add : t -> t -> t
    (** Arithmetic addition. *)

    val sub : t -> t -> t
    (** Arithmetic substraction *)

    val mul : t -> t -> t
    (** Arithmetic multiplication *)

    val div : t -> t -> t
    (** Real division. *)

    val lt : t -> t -> t
    (** Arithmetic "less than" comparison. *)

    val le : t -> t -> t
    (** Arithmetic "less or equal" comparison. *)

    val gt : t -> t -> t
    (** Arithmetic "greater than" comparison. *)

    val ge : t -> t -> t
    (** Arithmetic "greater or equal" comparison. *)
  end

  module Real_Int : sig
    type nonrec t = t
    (** The type of terms. *)

    type ty = Ty.t
    (** The type of types. *)

    val ty : t -> ty
    (** Get the type of a term. *)

    val int : string -> t
    (** Build an integer constant. The integer is passed
          as a string, and not an [int], to avoid overflow caused
          by the limited precision of native intgers. *)

    val real : string -> t
    (** Build a real constant. The string should respect
        smtlib's syntax for INTEGER or DECIMAL. *)

    (** Integer operations on terms *)
    module Int : sig
      val neg : t -> t
      (** Arithmetic negation. *)

      val add : t -> t -> t
      (** Arithmetic addition. *)

      val sub : t -> t -> t
      (** Arithmetic substraction *)

      val mul : t -> t -> t
      (** Arithmetic multiplication *)

      val div : t -> t -> t
      (** Integer division. See Smtlib theory for a full description. *)

      val modulo : t -> t -> t
      (** Integer remainder See Smtlib theory for a full description. *)

      val abs : t -> t
      (** Arithmetic absolute value. *)

      val lt : t -> t -> t
      (** Arithmetic "less than" comparison. *)

      val le : t -> t -> t
      (** Arithmetic "less or equal" comparison. *)

      val gt : t -> t -> t
      (** Arithmetic "greater than" comparison. *)

      val ge : t -> t -> t
      (** Arithmetic "greater or equal" comparison. *)

      val divisible : string -> t -> t
      (** Arithmetic divisibility predicate. Indexed over
          constant integers (represented as strings, see {!int}). *)

      val to_real : t -> t
      (** Conversion from an integer term to a real term. *)
    end

    (** Real operations on terms *)
    module Real : sig
      val neg : t -> t
      (** Arithmetic negation. *)

      val add : t -> t -> t
      (** Arithmetic addition. *)

      val sub : t -> t -> t
      (** Arithmetic substraction *)

      val mul : t -> t -> t
      (** Arithmetic multiplication *)

      val div : t -> t -> t
      (** Real division. *)

      val lt : t -> t -> t
      (** Arithmetic "less than" comparison. *)

      val le : t -> t -> t
      (** Arithmetic "less or equal" comparison. *)

      val gt : t -> t -> t
      (** Arithmetic "greater than" comparison. *)

      val ge : t -> t -> t
      (** Arithmetic "greater or equal" comparison. *)

      val is_int : t -> t
      (** Arithmetic predicate, true on reals that are also integers. *)

      val to_int : t -> t
      (** Total function from real to integers. Given a real r, return the
          largest integer n that satifies (<= (to_real n) r) *)
    end

  end

end
