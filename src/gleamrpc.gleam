import convert
import gleam/dynamic
import gleam/function
import gleam/option
import gleam/result

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

/// Error wrapper for GleamRPC
pub type GleamRPCClientError(error) {
  TransportError(error: error)
  DataDecodeError(error: List(dynamic.DecodeError))
  DataEncodeError(error: error)
}

/// An error that can occur during the execution of the implementation of a procedure
pub type ProcedureError {
  ProcedureError(message: String)
}

/// Errors that can occur of the server-side
pub type GleamRPCServerError(error) {
  WrongProcedure
  ProcedureExecError(error: ProcedureError)
  GetIdentityError(error)
  GetParamsError(errors: List(dynamic.DecodeError))
}

/// Routers are a way to organize procedures
pub type Router {
  Router(name: String, parent: option.Option(Router))
}

/// A procedure client is a way to transmit the data of the procedure to execute and get back its data.  
/// You should not create procedure clients directly, but rather use libraries such as `gleamrpc_http_client`.
pub type ProcedureClient(transport_in, transport_out, error) {
  ProcedureClient(
    encode_data: fn(ProcedureIdentity, convert.GlitrValue) ->
      Result(transport_in, GleamRPCClientError(error)),
    send_and_receive: fn(
      transport_in,
      fn(Result(transport_out, GleamRPCClientError(error))) -> Nil,
    ) ->
      Nil,
    decode_data: fn(transport_out, convert.GlitrType) ->
      Result(convert.GlitrValue, GleamRPCClientError(error)),
  )
}

/// A ProcedureCall combines a procedure and a procedure client.  
pub type ProcedureCall(transport_in, transport_out, params, return, error) {
  ProcedureCall(
    procedure: Procedure(params, return),
    client: ProcedureClient(transport_in, transport_out, error),
  )
}

/// A procedure server is a way to receive data and map it to the correct procedure implementation.  
/// It also handles parameter decoding, result encoding and error handling
/// You should not create procedure servers directly, but rather use libraries such as `gleamrpc_http_server`.
pub type ProcedureServer(transport_in, transport_out, error) {
  ProcedureServer(
    get_identity: fn(transport_in) ->
      Result(ProcedureIdentity, GleamRPCServerError(error)),
    get_params: fn(transport_in) ->
      fn(ProcedureType, convert.GlitrType) ->
        Result(convert.GlitrValue, GleamRPCServerError(error)),
    recover_error: fn(GleamRPCServerError(error)) -> transport_out,
    encode_result: fn(convert.GlitrValue) -> transport_out,
  )
}

/// A procedure handler is the heart of a procedure server.  
/// It is a function that actually does the procedure detection, parameter decoding and implementation call.  
/// You don't have to worry about this type, it is managed by the gleamrpc package.
pub type ProcedureHandler(context, error) =
  fn(
    ProcedureIdentity,
    fn(ProcedureType, convert.GlitrType) ->
      Result(convert.GlitrValue, GleamRPCServerError(error)),
    context,
  ) ->
    Result(convert.GlitrValue, GleamRPCServerError(error))

pub type ProcedureServerMiddleware(transport_in, transport_out) =
  fn(transport_in, fn(transport_in) -> transport_out) -> transport_out

/// A ProcedureServerInstance combines a procedure server and handler.  
/// It also manages context creation and procedure registration.
pub type ProcedureServerInstance(transport_in, transport_out, context, error) {
  ProcedureServerInstance(
    server: ProcedureServer(transport_in, transport_out, error),
    handler: ProcedureHandler(context, error),
    context_factory: fn(transport_in) -> context,
    middlewares: List(ProcedureServerMiddleware(transport_in, transport_out)),
  )
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

/// Execute the procedure call with the provided parameters.
/// It should be used with the 'use' syntax.
/// 
/// Example:
/// 
/// ```gleam
/// use data <- gleamrpc.call(my_procedure, my_params, my_client)
/// 
/// // do something with data
/// ``` 
pub fn call(
  procedure: Procedure(a, b),
  params: a,
  client: ProcedureClient(t_in, t_out, err),
  callback: fn(Result(b, GleamRPCClientError(err))) -> Nil,
) -> Nil {
  let identity =
    ProcedureIdentity(procedure.name, procedure.router, procedure.type_)
  let data = convert.encode(procedure.params_type)(params)

  case client.encode_data(identity, data) {
    Error(err) -> callback(Error(err))
    Ok(encoded_data) -> {
      use return_data <- client.send_and_receive(encoded_data)

      return_data
      |> result.then(client.decode_data(
        _,
        procedure.return_type |> convert.type_def,
      ))
      |> result.then(fn(v) {
        v
        |> convert.decode(procedure.return_type)
        |> result.map_error(DataDecodeError)
      })
      |> callback
    }
  }
}

// gleamrpc.with_server(http_server())
// |> gleamrpc.with_context(context_factory)
// |> gleamrpc.with_implementation(proc, impl)
// |> gleamrpc.with_implementation(proc2, impl2)
// |> gleamrpc.with_implementation(proc3, impl3)
// |> gleamrpc.serve()

/// Create a procedure server instance for a server
pub fn with_server(
  server: ProcedureServer(transport_in, transport_out, error),
) -> ProcedureServerInstance(transport_in, transport_out, transport_in, error) {
  ProcedureServerInstance(
    server,
    fn(_, _, _) { Error(WrongProcedure) },
    function.identity,
    [],
  )
}

/// Set the procedure server instance's context factory function  
/// It also unregisters all previously registered implementations, so it is better to call it first
pub fn with_context(
  server: ProcedureServerInstance(transport_in, transport_out, old_ctx, error),
  context_factory: fn(transport_in) -> context,
) -> ProcedureServerInstance(transport_in, transport_out, context, error) {
  ProcedureServerInstance(
    server: server.server,
    context_factory: context_factory,
    handler: fn(_, _, _) { Error(WrongProcedure) },
    middlewares: server.middlewares,
  )
}

/// Adds a middleware to be executed before/after executing the implementations.  
/// Can be used to transform input or output data or to conditionally short-circuit execution.
pub fn with_middleware(
  server: ProcedureServerInstance(transport_in, transport_out, ctx, error),
  middleware: ProcedureServerMiddleware(transport_in, transport_out),
) -> ProcedureServerInstance(transport_in, transport_out, ctx, error) {
  ProcedureServerInstance(..server, middlewares: [
    middleware,
    ..server.middlewares
  ])
}

/// Register a procedure's implementation in the provided server instance
pub fn with_implementation(
  server: ProcedureServerInstance(transport_in, transport_out, context, error),
  procedure: Procedure(params, return),
  implementation: fn(params, context) -> Result(return, ProcedureError),
) -> ProcedureServerInstance(transport_in, transport_out, context, error) {
  ProcedureServerInstance(
    ..server,
    handler: add_procedure(server.handler, procedure, implementation),
  )
}

/// Convert a server instance to a simple function 
/// 
/// Example : 
/// 
/// ```gleam
/// gleamrpc.with_server(http_server())
/// |> gleamrpc.with_implementation(my_procedure, implementation)
/// |> gleamrpc.serve
/// |> mist.new
/// |> mist.start_http
/// ```
pub fn serve(
  server: ProcedureServerInstance(transport_in, transport_out, context, error),
) -> fn(transport_in) -> transport_out {
  fn(in: transport_in) {
    use in <- execute_middlewares(in, server.middlewares)

    let result = {
      use identity <- result.try(server.server.get_identity(in))
      let params_fn = server.server.get_params(in)

      let context = server.context_factory(in)
      server.handler(identity, params_fn, context)
      |> result.map(server.server.encode_result)
    }

    case result {
      Ok(out) -> out
      Error(err) -> server.server.recover_error(err)
    }
  }
}

fn execute_middlewares(
  in: transport_in,
  middlewares: List(ProcedureServerMiddleware(transport_in, transport_out)),
  next: fn(transport_in) -> transport_out,
) -> transport_out {
  case middlewares {
    [] -> next(in)
    [middleware, ..rest] -> {
      use new_in <- middleware(in)
      execute_middlewares(new_in, rest, next)
    }
  }
}

fn add_procedure(
  handler: ProcedureHandler(context, error),
  procedure: Procedure(params, return),
  implementation: fn(params, context) -> Result(return, ProcedureError),
) -> ProcedureHandler(context, error) {
  fn(
    identity: ProcedureIdentity,
    params_fn: fn(ProcedureType, convert.GlitrType) ->
      Result(convert.GlitrValue, GleamRPCServerError(error)),
    context: context,
  ) {
    case handler(identity, params_fn, context) {
      Error(WrongProcedure) ->
        case identity {
          ProcedureIdentity(name, router, type_)
            if name == procedure.name
            && router == procedure.router
            && type_ == procedure.type_
          -> {
            use params <- result.try(params_fn(
              procedure.type_,
              procedure.params_type |> convert.type_def,
            ))

            params
            |> convert.decode(procedure.params_type)
            |> result.map_error(GetParamsError)
            |> result.then(fn(params) {
              implementation(params, context)
              |> result.map_error(ProcedureExecError)
            })
            |> result.map(convert.encode(procedure.return_type))
          }
          _ -> Error(WrongProcedure)
        }
      _ as result -> result
    }
  }
}
