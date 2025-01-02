import convert
import gleam/dynamic
import gleam/function
import gleam/option
import gleam/result

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

pub type ProcedureIdentity {
  ProcedureIdentity(
    name: String,
    router: option.Option(Router),
    type_: ProcedureType,
  )
}

pub type GleamRPCError(error) {
  GleamRPCError(error: error)
}

pub type GleamRPCServerError(error) {
  WrongProcedure
  ProcedureError(error)
  GetIdentityError(error)
  GetParamsError(error)
  DecodeError(error: List(dynamic.DecodeError))
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
    client: ProcedureClient(params, return, error),
  )
}

pub type ProcedureServer(transport_in, transport_out, error) {
  ProcedureServer(
    get_identity: fn(transport_in) ->
      Result(ProcedureIdentity, GleamRPCServerError(error)),
    get_params: fn(transport_in) ->
      Result(convert.GlitrValue, GleamRPCServerError(error)),
    recover_error: fn(GleamRPCServerError(error)) -> transport_out,
    encode_result: fn(convert.GlitrValue) -> transport_out,
  )
}

pub type ProcedureHandler(context, error) =
  fn(ProcedureIdentity, convert.GlitrValue, context) ->
    Result(convert.GlitrValue, GleamRPCServerError(error))

pub type ProcedureServerInstance(transport_in, transport_out, context, error) {
  ProcedureServerInstance(
    server: ProcedureServer(transport_in, transport_out, error),
    handler: ProcedureHandler(context, error),
    context_factory: fn(transport_in) -> context,
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
  client: ProcedureClient(a, b, c),
) -> ProcedureCall(a, b, c) {
  ProcedureCall(procedure, client)
}

pub fn call(
  procedure_call: ProcedureCall(a, b, c),
  params: a,
  callback: fn(Result(b, GleamRPCError(c))) -> Nil,
) -> Nil {
  procedure_call.client.call(procedure_call.procedure, params, callback)
}

// gleamrpc.with_server(http_server())
// |> gleamrpc.with_context(context_factory)
// |> gleamrpc.with_implementation(proc, impl)
// |> gleamrpc.with_implementation(proc2, impl2)
// |> gleamrpc.with_implementation(proc3, impl3)
// |> gleamrpc.serve()

pub fn with_server(
  server: ProcedureServer(transport_in, transport_out, error),
) -> ProcedureServerInstance(transport_in, transport_out, transport_in, error) {
  ProcedureServerInstance(
    server,
    fn(_, _, _) { Error(WrongProcedure) },
    function.identity,
  )
}

pub fn with_context(
  server: ProcedureServerInstance(transport_in, transport_out, _, error),
  context_factory: fn(transport_in) -> context,
) -> ProcedureServerInstance(transport_in, transport_out, context, error) {
  ProcedureServerInstance(..server, context_factory: context_factory)
}

pub fn with_implementation(
  server: ProcedureServerInstance(transport_in, transport_out, context, error),
  procedure: Procedure(params, return),
  implementation: fn(params, context) ->
    Result(return, GleamRPCServerError(error)),
) -> ProcedureServerInstance(transport_in, transport_out, context, error) {
  ProcedureServerInstance(
    ..server,
    handler: add_procedure(server.handler, procedure, implementation),
  )
}

pub fn serve(
  server: ProcedureServerInstance(transport_in, transport_out, context, error),
) -> fn(transport_in) -> transport_out {
  fn(in: transport_in) {
    let result = {
      use identity <- result.try(server.server.get_identity(in))
      use params <- result.try(server.server.get_params(in))

      let context = server.context_factory(in)
      server.handler(identity, params, context)
      |> result.map(server.server.encode_result)
    }

    case result {
      Ok(out) -> out
      Error(err) -> server.server.recover_error(err)
    }
  }
}

fn add_procedure(
  handler: ProcedureHandler(context, error),
  procedure: Procedure(params, return),
  implementation: fn(params, context) ->
    Result(return, GleamRPCServerError(error)),
) -> ProcedureHandler(context, error) {
  fn(identity: ProcedureIdentity, params: convert.GlitrValue, context: context) {
    case handler(identity, params, context) {
      Error(WrongProcedure) ->
        case identity {
          ProcedureIdentity(name, router, type_)
            if name == procedure.name
            && router == procedure.router
            && type_ == procedure.type_
          -> {
            params
            |> convert.decode(procedure.params_type)
            |> result.map_error(DecodeError)
            |> result.then(implementation(_, context))
            |> result.map(convert.encode(procedure.return_type))
          }
          _ -> Error(WrongProcedure)
        }
      _ as result -> result
    }
  }
}
