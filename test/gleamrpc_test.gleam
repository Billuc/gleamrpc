import convert
import convert/json as cjson
import gleam/bool
import gleam/int
import gleam/json
import gleam/option
import gleam/result
import gleam/string
import gleamrpc
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn create_query_test() {
  gleamrpc.query("test", option.None)
  |> should.equal(gleamrpc.Procedure(
    "test",
    option.None,
    gleamrpc.Query,
    convert.null(),
    convert.null(),
  ))
}

pub fn create_mutation_test() {
  gleamrpc.mutation("test_mutation", option.None)
  |> should.equal(gleamrpc.Procedure(
    "test_mutation",
    option.None,
    gleamrpc.Mutation,
    convert.null(),
    convert.null(),
  ))
}

pub fn create_with_router_test() {
  gleamrpc.query(
    "query_with_router",
    option.Some(gleamrpc.Router("router", option.None)),
  ).router
  |> should.be_some
  |> should.equal(gleamrpc.Router("router", option.None))
}

pub fn procedure_params_test() {
  gleamrpc.query("params", option.None)
  |> gleamrpc.params(convert.string())
  |> fn(proc) { proc.params_type }
  |> should.equal(convert.string())
}

pub fn procedure_return_test() {
  gleamrpc.query("returns", option.None)
  |> gleamrpc.returns(convert.list(convert.int()))
  |> fn(proc) { proc.return_type }
  |> should.equal(convert.list(convert.int()))
}

// This is a bad client example but it serves well for the purpose of the tests
fn mock_client() -> gleamrpc.ProcedureClient(String, String, String) {
  gleamrpc.ProcedureClient(
    encode_data: fn(_, v: convert.GlitrValue) {
      case v {
        convert.BoolValue(b) -> Ok(bool.to_string(b))
        convert.IntValue(i) -> Ok(int.to_string(i))
        convert.StringValue(s) -> Ok(s)
        _ -> Error(gleamrpc.DataEncodeError("wrong type"))
      }
    },
    send_and_receive: fn(
      in: String,
      cb: fn(Result(String, gleamrpc.GleamRPCClientError(String))) -> Nil,
    ) -> Nil {
      case in {
        "ping" -> cb(Ok("pong"))
        "beep" -> cb(Ok("boop"))
        "True" -> cb(Ok("False"))
        "1" -> cb(Ok("2"))
        _ -> cb(Error(gleamrpc.TransportError("can't transport that value")))
      }
    },
    decode_data: fn(out: String, type_: convert.GlitrType) -> Result(
      convert.GlitrValue,
      gleamrpc.GleamRPCClientError(String),
    ) {
      case out, type_ {
        "pong", convert.String | "boop", convert.String ->
          Ok(convert.StringValue(out))
        "False", convert.Bool -> Ok(convert.BoolValue(False))
        "2", convert.Int -> Ok(convert.IntValue(2))
        _, _ -> Error(gleamrpc.DataDecodeError([]))
      }
    },
  )
}

pub fn call_string_procedure_test() {
  let ping_procedure =
    gleamrpc.query("ping", option.None)
    |> gleamrpc.params(convert.string())
    |> gleamrpc.returns(convert.string())

  use res_ping <- gleamrpc.call(ping_procedure, "ping", mock_client())
  res_ping |> should.be_ok |> should.equal("pong")

  use res_beep <- gleamrpc.call(ping_procedure, "beep", mock_client())
  res_beep |> should.be_ok |> should.equal("boop")
}

pub fn call_wrong_string_procedure_test() {
  let ping_procedure =
    gleamrpc.query("ping", option.None)
    |> gleamrpc.params(convert.string())
    |> gleamrpc.returns(convert.string())

  use res_ping <- gleamrpc.call(ping_procedure, "blah", mock_client())
  res_ping
  |> should.be_error
  |> should.equal(gleamrpc.TransportError("can't transport that value"))
}

pub fn call_bool_procedure_test() {
  let procedure =
    gleamrpc.query("bool", option.None)
    |> gleamrpc.params(convert.bool())
    |> gleamrpc.returns(convert.bool())

  use res_ping <- gleamrpc.call(procedure, True, mock_client())
  res_ping |> should.be_ok |> should.equal(False)
}

pub fn call_int_procedure_test() {
  let procedure =
    gleamrpc.query("int", option.None)
    |> gleamrpc.params(convert.int())
    |> gleamrpc.returns(convert.int())

  use res_ping <- gleamrpc.call(procedure, 1, mock_client())
  res_ping |> should.be_ok |> should.equal(2)
}

pub fn call_unsupported_type_procedure_test() {
  let procedure =
    gleamrpc.query("float", option.None)
    |> gleamrpc.params(convert.float())
    |> gleamrpc.returns(convert.float())

  use res_ping <- gleamrpc.call(procedure, 1.25, mock_client())
  res_ping
  |> should.be_error
  |> should.equal(gleamrpc.DataEncodeError("wrong type"))
}

fn mock_server() -> gleamrpc.ProcedureServer(String, String, String) {
  gleamrpc.ProcedureServer(
    get_identity: fn(in_data: String) {
      case in_data |> string.split_once(":") {
        Ok(#(name, _rest)) ->
          Ok(gleamrpc.ProcedureIdentity(name, option.None, gleamrpc.Query))
        _ -> Error(gleamrpc.GetIdentityError("No procedure name"))
      }
    },
    get_params: fn(in_data: String) {
      fn(_proc_type, glitr_type) {
        in_data
        |> string.split_once(":")
        |> result.replace_error(gleamrpc.GetIdentityError("No procedure name"))
        |> result.then(fn(v) {
          case glitr_type {
            convert.Int ->
              int.parse(v.1)
              |> result.map(convert.IntValue)
              |> result.replace_error(gleamrpc.GetParamsError([]))
            convert.String -> Ok(convert.StringValue(v.1))
            convert.Bool -> Ok(convert.BoolValue(v.1 == "True"))
            _ -> Error(gleamrpc.GetParamsError([]))
          }
        })
      }
    },
    recover_error: fn(_error) { "Error" },
    encode_result: fn(value: convert.GlitrValue) {
      cjson.encode_value(value) |> json.to_string()
    },
  )
}

pub fn simple_server_test() {
  let ping_procedure =
    gleamrpc.query("ping", option.None)
    |> gleamrpc.params(convert.string())
    |> gleamrpc.returns(convert.string())

  let server_fn =
    gleamrpc.with_server(mock_server())
    |> gleamrpc.with_implementation(ping_procedure, fn(data, _ctx) {
      case data {
        "ping" -> Ok("pong")
        _ -> Error(gleamrpc.ProcedureError("unexpected_data"))
      }
    })
    |> gleamrpc.serve

  server_fn("ping:ping")
  |> should.equal("\"pong\"")
}
