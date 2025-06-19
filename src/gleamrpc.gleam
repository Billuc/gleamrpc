import convert
import gleam/option

pub type ProcedureType {
  /// A query is a procedure that does not alter data, only retrieves it
  Query
  /// A mutation is a procedure that alters data (think create, update, delete)
  Mutation
  // Subscription
}

/// A procedure is the equivalent of a function, but the execution of this function can be done remotely
pub type Procedure(params, return) {
  Procedure(
    name: String,
    router: option.Option(Router),
    type_: ProcedureType,
    params_type: convert.Converter(params),
    return_type: convert.Converter(return),
  )
}

/// This is only useful for ProcedureServers
pub type ProcedureIdentity {
  ProcedureIdentity(
    name: String,
    router: option.Option(Router),
    type_: ProcedureType,
  )
}

/// Routers are a way to organize procedures
pub type Router {
  Router(name: String, parent: option.Option(Router))
}

/// Create a Query procedure
pub fn query(name: String, router: option.Option(Router)) -> Procedure(Nil, Nil) {
  Procedure(name, router, Query, convert.null(), convert.null())
}

/// Create a Mutation procedure
pub fn mutation(
  name: String,
  router: option.Option(Router),
) -> Procedure(Nil, Nil) {
  Procedure(name, router, Mutation, convert.null(), convert.null())
}

/// Set the parameter type of the provided procedure
pub fn params(
  procedure: Procedure(_, b),
  params_converter: convert.Converter(a),
) -> Procedure(a, b) {
  Procedure(..procedure, params_type: params_converter)
}

/// Set the return type of the provided procedure
pub fn returns(
  procedure: Procedure(a, _),
  return_converter: convert.Converter(b),
) -> Procedure(a, b) {
  Procedure(..procedure, return_type: return_converter)
}
