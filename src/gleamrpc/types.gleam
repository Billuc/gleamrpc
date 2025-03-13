import gleam/dict
import gleam/dynamic
import gleam/option

pub type JsonRpcRequest(params) {
  JsonRpcRequest(id: Int, jsonrpc: String, method: String, params: params)
}

pub type JsonRpcResponse(result) {
  JsonRpcResponse(id: Int, jsonrpc: String, result: result)
}

pub type OpenRpcDocument {
  OpenRpcDocument(
    /// Must be the semantic version number of the OpenRPC specification version used
    openrpc: String,
    info: OpenRpcInfo,
    methods: List(OpenRpcMethod),
    servers: option.Option(List(OpenRpcServer)),
    components: option.Option(OpenRpcComponents),
    external_docs: option.Option(OpenRpcExternalDocs),
  )
}

pub type OpenRpcInfo {
  OpenRpcInfo(
    version: String,
    title: String,
    description: option.Option(String),
    terms_of_service: option.Option(String),
    contact: option.Option(OpenRpcContact),
    license: option.Option(OpenRpcLicense),
  )
}

pub type OpenRpcContact {
  OpenRpcContact(
    name: option.Option(String),
    url: option.Option(String),
    email: option.Option(String),
  )
}

pub type OpenRpcLicense {
  OpenRpcLicense(name: String, url: option.Option(String))
}

pub type OpenRpcServer {
  OpenRpcServer(
    name: String,
    url: OpenRpcRuntimeExpression,
    summary: option.Option(String),
    description: option.Option(String),
    variables: option.Option(dict.Dict(String, OpenRpcServerVariableObject)),
  )
}

pub type OpenRpcServerVariableObject {
  OpenRpcServerVariableObject(
    enum: option.Option(List(String)),
    default: String,
    description: option.Option(String),
  )
}

pub type OpenRpcTag {
  TagTagObject(data: OpenRpcTagObject)
  TagReferenceObject(data: OpenRpcReferenceObject)
}

pub type OpenRpcMethod {
  OpenRpcMethod(
    name: String,
    tags: option.Option(List(OpenRpcTag)),
    summary: option.Option(String),
    description: option.Option(String),
    params: List(OpenRpcParam),
    result: option.Option(OpenRpcResult),
    deprecated: option.Option(Bool),
    servers: option.Option(List(OpenRpcServer)),
    errors: option.Option(List(OpenRpcError)),
    links: option.Option(List(OpenRpcLink)),
    param_structure: option.Option(OpenRpcParamStructure),
    examples: option.Option(List(OpenRpcExamplePairing)),
  )
}

pub type OpenRpcParam {
  ParamContentDescriptor(data: OpenRpcContentDescriptor)
  ParamReferenceObject(data: OpenRpcReferenceObject)
}

pub type OpenRpcResult {
  ResultContentDescriptor(data: OpenRpcContentDescriptor)
  ResultReferenceObject(data: OpenRpcReferenceObject)
}

pub type OpenRpcError {
  ErrorErrorObject(data: OpenRpcErrorObject)
  ErrorReferenceObject(data: OpenRpcReferenceObject)
}

pub type OpenRpcParamStructure {
  ByName
  ByPosition
  Either
}

pub type OpenRpcExamplePairing {
  ExamplePairingExamplePairingObject(data: OpenRpcExamplePairingObject)
  ExamplePairingReferenceObject(data: OpenRpcReferenceObject)
}

pub type OpenRpcContentDescriptor {
  OpenRpcContentDescriptor(
    name: String,
    summary: option.Option(String),
    description: option.Option(String),
    required: option.Option(Bool),
    schema: OpenRpcSchema,
    deprecated: option.Option(String),
  )
}

// TODO
pub type OpenRpcSchema {
  OpenRpcString
  OpenRpcArray(items: OpenRpcSchema)
  OpenRpcObject(title: String, properties: dict.Dict(String, OpenRpcSchema))
}

pub type OpenRpcExamplePairingObject {
  OpenRpcExamplePairingObject(
    name: String,
    description: option.Option(String),
    summary: option.Option(String),
    params: List(OpenRpcExample),
    result: option.Option(OpenRpcExample),
  )
}

pub type OpenRpcExample {
  ExampleExampleObject(data: OpenRpcExampleObject)
  ExampleReferenceObject(data: OpenRpcReferenceObject)
}

// TODO : validate example values
pub type OpenRpcExampleObject {
  OpenRpcExampleObject(
    name: option.Option(String),
    summary: option.Option(String),
    description: option.Option(String),
    value: OpenRpcValue,
  )
}

pub type OpenRpcValue {
  OpenRpcValue(data: dynamic.Dynamic)
  OpenRpcExternalValue(data: String)
}

pub type OpenRpcLink {
  LinkLinkObject(data: OpenRpcLinkObject)
  LinkReferenceObject(data: OpenRpcReferenceObject)
}

// TODO : verify method
pub type OpenRpcLinkObject {
  OpenRpcLinkObject(
    name: String,
    description: option.Option(String),
    summary: option.Option(String),
    method: option.Option(String),
    params: option.Option(dict.Dict(String, OpenRpcLinkValue)),
    server: option.Option(OpenRpcServer),
  )
}

pub type OpenRpcLinkValue {
  ValueDynamicValue(data: dynamic.Dynamic)
  ValueRuntimeExpression(data: OpenRpcRuntimeExpression)
}

pub type OpenRpcRuntimeExpression {
  OpenRpcRuntimeExpression
}

pub type OpenRpcErrorObject {
  OpenRpcErrorObject(
    code: Int,
    message: String,
    data: option.Option(dynamic.Dynamic),
  )
}

// TODO : check keys match ^[a-zA-Z0-9\.\-_]+$
pub type OpenRpcComponents {
  OpenRpcComponents(
    content_descriptors: option.Option(
      dict.Dict(String, OpenRpcContentDescriptor),
    ),
    schemas: option.Option(dict.Dict(String, OpenRpcSchema)),
    examples: option.Option(dict.Dict(String, OpenRpcExampleObject)),
    links: option.Option(dict.Dict(String, OpenRpcLinkObject)),
    errors: option.Option(dict.Dict(String, OpenRpcErrorObject)),
    example_pairing_objects: option.Option(
      dict.Dict(String, OpenRpcExamplePairingObject),
    ),
    tags: option.Option(dict.Dict(String, OpenRpcTagObject)),
  )
}

pub type OpenRpcTagObject {
  OpenRpcTagObject(
    name: String,
    summary: option.Option(String),
    description: option.Option(String),
    external_docs: option.Option(OpenRpcExternalDocs),
  )
}

pub type OpenRpcExternalDocs {
  OpenRpcExternalDocs(description: option.Option(String), url: String)
}

pub type OpenRpcReferenceObject {
  OpenRpcReferenceObject(ref: String)
}
