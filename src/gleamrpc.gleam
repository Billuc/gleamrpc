import convert
import gleam/option

pub type ProcedureType {
  Query
  Mutation
  // Subscription
}

pub type Procedure(params, return) {
  Procedure(
    name: String,
    router: option.Option(Router),
    type_: ProcedureType,
    params_type: convert.Converter(params),
    return_type: convert.Converter(return),
  )
}

pub type GleamRPCError(error) {
  GleamRPCError(error: error)
}

pub type Router {
  Router(name: String, parent: option.Option(Router))
}

pub type ProcedureClient(params, return, error) {
  ProcedureClient(
    call: fn(
      Procedure(params, return),
      params,
      fn(Result(return, GleamRPCError(error))) -> Nil,
    ) ->
      Nil,
  )
}

pub type ProcedureCall(params, return, error) {
  ProcedureCall(
    procedure: Procedure(params, return),
    server: ProcedureClient(params, return, error),
  )
}

pub fn query(name: String, router: option.Option(Router)) -> Procedure(Nil, Nil) {
  Procedure(name, router, Query, convert.null(), convert.null())
}

pub fn mutation(
  name: String,
  router: option.Option(Router),
) -> Procedure(Nil, Nil) {
  Procedure(name, router, Mutation, convert.null(), convert.null())
}

pub fn params(
  procedure: Procedure(_, b),
  params_converter: convert.Converter(a),
) -> Procedure(a, b) {
  Procedure(..procedure, params_type: params_converter)
}

pub fn returns(
  procedure: Procedure(a, _),
  return_converter: convert.Converter(b),
) -> Procedure(a, b) {
  Procedure(..procedure, return_type: return_converter)
}

pub fn with_client(
  procedure: Procedure(a, b),
  server: ProcedureClient(a, b, c),
) -> ProcedureCall(a, b, c) {
  ProcedureCall(procedure, server)
}

pub fn call(
  procedure_call: ProcedureCall(a, b, c),
  params: a,
  callback: fn(Result(b, GleamRPCError(c))) -> Nil,
) -> Nil {
  procedure_call.server.call(procedure_call.procedure, params, callback)
}
