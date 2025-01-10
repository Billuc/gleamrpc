import convert
import gleam/bool
import gleam/int
import gleam/option
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
