(*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

open Pyre

module ClassDefinitionsCache : sig
  val invalidate : unit -> unit
end

module T : sig
  type breadcrumbs = Features.Simple.t list [@@deriving show, compare]

  type leaf_kind =
    | Leaf of {
        name: string;
        subkind: string option;
      }
    | Breadcrumbs of breadcrumbs

  type taint_annotation =
    | Sink of {
        sink: Sinks.t;
        breadcrumbs: breadcrumbs;
        path: Abstract.TreeDomain.Label.path;
        leaf_names: Features.LeafName.t list;
        leaf_name_provided: bool;
      }
    | Source of {
        source: Sources.t;
        breadcrumbs: breadcrumbs;
        path: Abstract.TreeDomain.Label.path;
        leaf_names: Features.LeafName.t list;
        leaf_name_provided: bool;
      }
    | Tito of {
        tito: Sinks.t;
        breadcrumbs: breadcrumbs;
        path: Abstract.TreeDomain.Label.path;
      }
    | AddFeatureToArgument of {
        breadcrumbs: breadcrumbs;
        path: Abstract.TreeDomain.Label.path;
      }

  type annotation_kind =
    | ParameterAnnotation of AccessPath.Root.t
    | ReturnAnnotation
  [@@deriving show, compare]

  module ModelQuery : sig
    type annotation_constraint = IsAnnotatedTypeConstraint [@@deriving compare, show]

    type parameter_constraint = AnnotationConstraint of annotation_constraint
    [@@deriving compare, show]

    type name_constraint =
      | Equals of string
      | Matches of Re2.t
    [@@deriving compare, show]

    type class_constraint =
      | NameSatisfies of name_constraint
      | Extends of {
          class_name: string;
          is_transitive: bool;
        }
    [@@deriving compare, show]

    type model_constraint =
      | NameConstraint of name_constraint
      | ReturnConstraint of annotation_constraint
      | AnyParameterConstraint of parameter_constraint
      | AnyOf of model_constraint list
      | ParentConstraint of class_constraint
      | DecoratorNameConstraint of string
      | Not of model_constraint
    [@@deriving compare, show]

    type kind =
      | FunctionModel
      | MethodModel
      | AttributeModel
    [@@deriving show, compare]

    type produced_taint =
      | TaintAnnotation of taint_annotation
      | ParametricSourceFromAnnotation of {
          source_pattern: string;
          kind: string;
        }
      | ParametricSinkFromAnnotation of {
          sink_pattern: string;
          kind: string;
        }
    [@@deriving show, compare]

    type production =
      | AllParametersTaint of {
          excludes: string list;
          taint: produced_taint list;
        }
      | ParameterTaint of {
          name: string;
          taint: produced_taint list;
        }
      | PositionalParameterTaint of {
          index: int;
          taint: produced_taint list;
        }
      | ReturnTaint of produced_taint list
      | AttributeTaint of produced_taint list
    [@@deriving show, compare]

    type rule = {
      query: model_constraint list;
      productions: production list;
      rule_kind: kind;
      name: string option;
    }
    [@@deriving show, compare]
  end

  type parse_result = {
    models: TaintResult.call_model Interprocedural.Callable.Map.t;
    queries: ModelQuery.rule list;
    skip_overrides: Ast.Reference.Set.t;
    errors: ModelVerificationError.t list;
  }
end

val parse
  :  resolution:Analysis.Resolution.t ->
  ?path:Path.t ->
  ?rule_filter:int list ->
  source:string ->
  configuration:TaintConfiguration.t ->
  TaintResult.call_model Interprocedural.Callable.Map.t ->
  T.parse_result

val verify_model_syntax : path:Path.t -> source:string -> unit

val compute_sources_and_sinks_to_keep
  :  configuration:TaintConfiguration.t ->
  rule_filter:int list option ->
  Sources.Set.t option * Sinks.Set.t option

val create_callable_model_from_annotations
  :  resolution:Analysis.Resolution.t ->
  callable:Interprocedural.Callable.real_target ->
  sources_to_keep:Sources.Set.t option ->
  sinks_to_keep:Sinks.Set.t option ->
  (T.annotation_kind * T.taint_annotation) list ->
  (TaintResult.call_model, ModelVerificationError.t) result

val create_attribute_model_from_annotations
  :  resolution:Analysis.Resolution.t ->
  name:Ast.Reference.t ->
  sources_to_keep:Sources.Set.t option ->
  sinks_to_keep:Sinks.Set.t option ->
  T.taint_annotation list ->
  (TaintResult.call_model, ModelVerificationError.t) result
