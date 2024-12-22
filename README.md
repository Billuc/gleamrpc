# gleamrpc

[![Package Version](https://img.shields.io/hexpm/v/gleamrpc)](https://hex.pm/packages/gleamrpc)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gleamrpc/)

Remote Procedure Calls in Gleam !

Note that this library isn't a standalone library, you will need a client and a server implementations.  
See gleamrpc_http_client and gleamrpc_http_server for HTTP implementations.

```sh
gleam add gleamrpc@1
```
```gleam
import convert
import gleam/option
import gleamrpc

pub fn main() {
  let id_query_convert = convert.object({
	  use id <- convert.field("id", fn(v) { Ok(v.id) }, convert.string())
    convert.success(IdQuery(id))
  })
  |> convert.map(
    fn (v: IdQuery) { v.id },
    fn (v: String) { Ok(IdQuery(v)) },
    ""
  )
  let user_convert = convert.object({
    use id <- convert.field("id", fn(v) { Ok(v.id) }, convert.string())
    use name <- convert.field("name", fn(v) { Ok(v.name) }, convert.string())
    use age <- convert.field("age", fn(v) { Ok(v.age) }, convert.int())
    convert.success(User(id, name, age))
  })

  let users_router = gleamrpc.Router("users", option.None) // /api/gleamRPC/users
  let get_user = gleamrpc.query("get_user", option.Some(users_router))
    |> gleamrpc.params(id_query_convert) // /api/gleamRPC/users/get_user?id=<ID>
    |> gleamrpc.returns(user_convert)

  // user is of type Result(User, gleamrpc.GleamRPCError)
  use user <- get_user
    |> gleamrpc.with_client(client) // client is provided by the implementation you choose
    |> gleamrpc.call("1")

  // Do something with your user
}
```

Further documentation can be found at <https://hexdocs.pm/gleamrpc>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
