import convert
import gleam/option
import gleamrpc
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn create_query_test() {
  let procedure = gleamrpc.query("test", option.None)

  procedure.name |> should.equal("test")
  procedure.router |> should.be_none
  procedure.type_ |> should.equal(gleamrpc.Query)
  procedure.params_type |> convert.type_def |> should.equal(convert.Null)
  procedure.return_type |> convert.type_def |> should.equal(convert.Null)
}

pub fn create_mutation_test() {
  let procedure = gleamrpc.mutation("test_mutation", option.None)

  procedure.name |> should.equal("test_mutation")
  procedure.router |> should.be_none
  procedure.type_ |> should.equal(gleamrpc.Mutation)
  procedure.params_type |> convert.type_def |> should.equal(convert.Null)
  procedure.return_type |> convert.type_def |> should.equal(convert.Null)
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
  |> fn(proc) { proc.params_type |> convert.type_def }
  |> should.equal(convert.String)
}

pub fn procedure_return_test() {
  gleamrpc.query("returns", option.None)
  |> gleamrpc.returns(convert.list(convert.int()))
  |> fn(proc) { proc.return_type |> convert.type_def }
  |> should.equal(convert.List(convert.Int))
}
