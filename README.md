<img src="https://swift.org/assets/images/swift.svg" alt="Swift logo" height="70" >
# Swift Protobuf Plugin

**Welcome to Swift Protobuf!**

Apple's Swift programming language is a perfect complement to Google's Protocol
Buffer serialization technology.  They both emphasize high performance
and programmer safety.

This project provides complete support for Protocol Buffer via a protoc
_plugin_ that is itself written entirely in Swift.

For more information about Swift Protobuf, please look at:
* [Swift Protobuf Runtime Library](https://github.com/apple/swift-protobuf-runtime)
* [Swift Protobuf Conformance Checker](https://github.com/apple/swift-protobuf-test-conformance)

## Getting Started

If you've worked with Protocol Buffers before, adding Swift support is very simple:  you just need to build the `protoc-gen-swift` program and copy it into your PATH.  The protoc program will find and use it automatically, allowing you to build Swift sources for your proto files.  You will also, of course, need to add the corresponding Swift runtime library to your project.

### System Requirements

To use Swift with Protocol buffers, you'll need:

* A recent Swift 3 compiler that includes the Swift Package Manager.  The Swift protobuf project is being developed and tested against the Swift 3.0 developer preview available from [Swift.org](https://swift.org)

* Google's protoc compiler.  The Swift protoc plugin is being actively developed and tested against the protobuf 3.0 release.  It may work with earlier versions of protoc.  You can get recent versions from [Google's github repository](https://github.com/google/protobuf).

### Build and Install

Building the plugin should be simple on any supported Swift platform:
```
$ git clone https://github.com/apple/swift-protobuf-plugin
$ cd swift-protobuf-plugin
$ swift build
```
This will create a binary called `protoc-gen-swift` in the `.build/debug` directory.  To install, just copy this one executable anywhere in your PATH.

### Converting .proto files into Swift

To generate Swift output for your .proto files, you run the `protoc` command as usual, using the `--swift_out=<directory>` option:

```
$ protoc --swift_out=. my.proto
```

The `protoc` program will automatically look for `protoc-gen-swift` in your `PATH` and use it.

Each `.proto` input file will get translated to a corresponding `.pb.swift` file in the output directory.

### Building your project

After copying the `.pb.swift` files into your project, you will need to add the [SwiftProtobufRuntime library](https://github.com/apple/swift-protobuf-runtime) to your project to support the generated code.  If you are using the Swift Package Manager, you should first check what version of `protoc-gen-swift` you are currently using:
```
$ protoc-gen-swift --version
protoc-gen-swift 0.9.12
```

And then add a dependency to your Package.swift file.  Adjust the `Version()` here to match the `protoc-gen-swift` version you checked above:
```
dependencies: [
        .Package(url: "https://github.com/apple/swift-protobuf-runtime.git", Version(0,9,12))
]
```

If you are using Xcode, then you should:
* Add the Swift source files generated from your protos directly to your project
* Clone the SwiftProtobufRuntime package
* Add the SwiftProtobufRuntime target from the Xcode project from that package to your project.

# Quick Example

Here is a quick example to illustrate how you can use Swift Protocol Buffers in your program, and why you might want to.  Create a file `DataModel.proto` with the following contents:

```
syntax = "proto3";

message BookInfo {
   int64 id = 1;
   string title = 2;
   string author = 3;
}

message MyLibrary {
   int64 id = 1;
   string name = 2;
   repeated BookInfo books = 3;
   map<string,string> keys = 4;
}
```

After saving the above, you can generate Swift code using the following command:

```
$ protoc --swift_out=. DataModel.proto
```

This will create a file `DataModel.pb.swift` with a `struct BookInfo` and a `struct MyLibrary` with corresponding Swift fields for each of the proto fields and a host of other capabilities:

* Full mutable Swift copy-on-write value semantics
* CustomDebugStringConvertible:  The generated struct has a debugDescription method that can dump a full representation of the data
* Hashable, Equatable:  The generated struct can be put into a `Set<>` or `Dictionary<>`
* Binary serializable:  The `.serializeProtobuf()` method returns a `[UInt8]` with a compact binary form of your data.  You can deserialize the data using the `init(protobuf:)` initializer.
* JSON serializable:  The `.serializeJSON()` method returns a flexible JSON representation of your data that can be parsed with the `init(json:)` initializer.
* Portable:  The binary and JSON formats used by the serializers here are identical to those supported by protobuf for many other platforms and languages, making it easy to talk to C++ or Java servers, share data with desktop apps written in Objective-C or C++, or work with system applications developed in Python or Go.

And of course, you can define your own Swift extensions to the generated `MyLibrary` struct to augment it with additional custom capabilities.

Best of all, you can take the same `DataModel.proto` file and generate Java, C++, Python, or Objective-C for use on other platforms. Those platforms can all then exchange serialized data in binary or JSON forms, with no additional effort on your part.

# Generated Code

The following describes how each construct in a `.proto` file gets translated into Swift language constructs:

**Files:** Each input `.proto` file generates a single output file with the `.proto` extension replaced with `.pb.swift`.

**Messages:** Each input message generates a single output struct that conforms to the `ProtobufMessageType` protocol.  Small leaf messages (those that don't have message-typed fields) generate simple structs.  Non-leaf messages use a private copy-on-write backing class to provide full value semantics while also supporting recursive data structures.  Nested messages generate nested struct types so that
```
package quux;
message Foo {
   message Bar {
      int32 baz = 1;
   }
   Bar bar = 1;
}
```
will be compiled to a structure like the following
```
public struct QuuxFoo {
    // ...
    public struct Bar {
        // ...
        var baz: Int32 {get set}
        // ...
    }
    var bar: Bar {get set}
    // ...
}
```
which you can use as follows:
```
   var foo = QuuxFoo()
   foo.bar.baz = 77
```

**Groups:** Each group within a message generates a nested struct.  The group struct implements the `ProtobufGroupType` protocol which differs from `ProtobufMessageType` primarily in how it handles serialization and deserialization (you do not normally need to be aware of this).  Note that groups are deprecated and only available with the older 'proto2' language dialect.

**Binary Serialization and Deserialization:**  You can serialize to a `[UInt8]` using the `serializeProtobuf()` method or deserialize with the corresponding initializer:
```
init(protobuf: [UInt8]) throws
func serializeProtobuf() throws -> [UInt8]
```
Protobuf binary serialization can currently only fail if the data includes Any fields that were decoded from JSON format.  See below for details.

Unrecognized fields are preserved through decoding/encoding cycles for proto2 messages.  Unrecognized fields are dropped for proto3 messages.

**JSON Serialization and Deserialization:**  Similarly, JSON serialization is handled by `serializeJSON()` which returns a `String` with the result.  Deserialization is handled by the corresponding initializer:
```
init(json: String) throws
func serializeJSON() throws -> String
```
JSON serialization can fail if there are Any fields that were decoded from binary protobuf format, or if you abuse the well-known Timestamp, Duration, or FieldMask types.

**Other Message Features:** All messages conform to `Hashable`, `Equatable`, and `CustomDebugStringConvertible`.  All generated objects include an `isEmpty` property that returns `true` if the object would test equal to a newly-created unmodified object.

**Convenience Initializer:** Messages that have fields gain an additional convenience intializer that has an argument for every field.  The arguments are defaulted so you can specify only the ones you actually need to set.

**Fields:**  Each field is compiled into a property on the struct.  Field names are converted from `snake_case` conventions in the proto file to `lowerCamelCase` property names in the Swift file.  If the result conflicts with a reserved word, an underscore will be appended to the property name.

**Optional Fields:**  Optional fields generate Swift Optional properties. Such properties have a default value of `nil` unless overridden in the .proto file. You can assign `nil` to any such property to reset it to the default.  For optional fields without a default, you can test whether the field is `nil` to see if it has been set.  There is currently no way to test if optional fields that do have defaults have been set.

When serializing an optional field, the field is serialized if it has been set to a non-nil value.  In particular, fields with defaults are not serialized if they have been reset by writing 'nil' but are serialized if you explicitly set them to the default value.

**Required Fields:**  Required fields generate non-Optional properties.  All such properties return suitable default values when read.  If no default value is specified in the .proto, numeric fields default to zero, boolean fields default to false, string fields default to the empty string, byte fields default to the empty array, enum fields default to the appropriate default enum value, and message fields default to an empty object of that type.  Currently, required fields are always serialized, even if they have not been changed from their default.  This may change.

**Repeated Fields:** Repeated fields generate array-valued properties. All such properties default to an empty array.

**Map:** Map fields generate Dictionary-valued properties. When read, these properties default to an empty dictionary.  The dictionary values can be mutated directly.

**Proto3 Singular Fields:**  Proto3 does not support required or optional fields.  Singular proto3 fields generate non-optional Swift properties.  These fields are initialized to the appropriate Proto3 default value (zero for numeric fields, false for booleans, etc.)  They are serialized if they have a non-default value.

**Proto3 Singular message Fields:**  Proto3 singular message fields behave externally as other singular fields.  In particular, reading such a field returns a valid empty message object by default.  Internally, however, singular message fields are in fact stored as Swift optionals, but this is only done as an optimization and is not visible to clients.

**Enums:** Each enum in the proto file generates a Swift enum that implements RawRepresentable with a base type of Int. The enum is nested within an enclosing message, if any. The enum contains the specified cases from the source .proto plus an extra `UNRECOGNIZED(Int)` case that is used to carry unknown enum values when decoding binary protobuf format.  Enums with duplicate cases (more than one case with the same integer value) are fully supported.

**Oneof:** Each oneof field generates an enum with a case for each field in the oneof block. The containing message provides an accessor for the oneof field itself that allows you to set or get the enum value directly and allows you to use a `switch` or `if case` statement to conditionally handle the contents. The containing message also provides shortcut accessors for each field in the oneof that will return the corresponding value if present or `nil` if that value is not present.

**Reflection:**  The standard Swift Mirror() facility can be used to inspect the fields on generated messages.  Fields appear in the reflection if they would be serialized.  In particular, proto2 required fields are always included, proto2 optional fields are included if they are non-nil, and proto3 singular fields are included if they do not have a default value.

**Extensions:**  Each extension in a proto file generates two distinct components:

* An extension object that defines the type, field number, and other properties of the extension.  This is defined at a scope corresponding to where the proto extension was defined.

* A Swift extension of the message struct that provides natural property access for the extension value on that message struct.

Each generated Swift file that defines extensions also has a static constant holding a ProtobufExtensionSet with all extensions declared in that file.

To decode a message with extensions, you need to first obtain or construct a ProtobufExtensionSet holding extension objects for all of the extensions you want to support.  A single ProtobufExtensionSet can hold any number of extensions for any number of messages.  You then provide this set to the deserializing initializer which will use it to identify and deserialize extension fields.

You need do nothing special to have extension values properly serialized.

To set or read extension properties, you simply use the standard property access.

Caveat:  Extensions are not available in proto3.

**Any:**  The Any message type is included in the runtime package as `Google_Protobuf_Any`.  You can construct a message from a `Google_Protobuf_Any` value via a convenience initializer available on any ProtobufMessageType: `init?(any: Google_Protobuf_Any)`.  You can similarly construct a `Google_Protobuf_Any` object from any message using `Google_Protobuf_Any(message: ProtobufMessageType)`.  To support this, each generated message includes a property `anyTypeURL` containing the URL for that message type.  This URL is included in the Any object when one is constructed from a message, and is checked when constructing a message from an Any.  Caveat:  Although Any fields can be encoded in both binary protobuf and JSON, Google's spec places limits on translations between these two codings.  As a result, you should be careful with Any fields if you expect to use both JSON and protobuf encodings.

**Well-known types:**  Google has defined a number of "well-known types" as part of proto3.  These are predefined messages that support common idioms.  These well-known types are precompiled and bundled into the Swift runtime:

| Proto Type                  |  Swift Type               |
| -------------------------   | -----------------------   |
| google.protobuf.Any         | Google_Protobuf_Any         |
| google.protobuf.Api         | Google_Protobuf_Api         |
| google.protobuf.BoolValue   | Google_Protobuf_BoolValue   |
| google.protobuf.BytesValue  | Google_Protobuf_BytesValue  |
| google.protobuf.DoubleValue | Google_Protobuf_DoubleValue |
| google.protobuf.Duration    | Google_Protobuf_Duration    |
| google.protobuf.Empty       | Google_Protobuf_Empty       |
| google.protobuf.FieldMask   | Google_Protobuf_FieldMask   |
| google.protobuf.FloatValue  | Google_Protobuf_FloatValue  |
| google.protobuf.Int64Value  | Google_Protobuf_Int64Value  |
| google.protobuf.ListValue   | Google_Protobuf_ListValue   |
| google.protobuf.StringValue | Google_Protobuf_StringValue |
| google.protobuf.Struct      | Google_Protobuf_Struct      |
| google.protobuf.Timestamp   | Google_Protobuf_Timestamp   |
| google.protobuf.Type        | Google_Protobuf_Type        |
| google.protobuf.UInt32Value | Google_Protobuf_UInt32Value |
| google.protobuf.UInt64Value | Google_Protobuf_UInt64Value |
| google.protobuf.Value       | Google_Protobuf_Value       |


To use the well-known types in your own protos, you will need to have the corresponding protos available so you can `import` them into your proto file.  However, the compiled forms of these types are already available in the library; you do not need to compile them or do anything to use them other than `import Protobuf`.

## Aside:  proto2 vs. proto3

The terms *proto2* and *proto3* refer to two different dialects of the proto *language.*  The older proto2 language dates back to 2008, the proto3 language was introduced in 2015.  These should not be confused with versions of the protobuf *project* or the protoc *program*.  In particular, the protoc 3.0 program has solid support for both proto2 and proto3 language dialects.  Many people continue to use the proto2 language with protoc 3.0 because they have existing systems that depend on particular features of the proto2 language that were changed in proto3.

# Examples

Following are a number of examples demonstrating how to use the code generated by protoc in a Swift program.

## Basic Protobuf Serialization

Consider this simple proto file:

```
// file foo.proto
package project.basics;
syntax = "proto3";
message Foo {
   int32 id = 1;
   string label = 2;
   repeated string alternates = 3;
}
```

After running protoc, you will have a Swift source file `foo.pb.swift` that contains a `struct Project_Basics_Foo`.  The name here includes a prefix derived from the package name; you can override this prefix with the `swift_prefix` option.

You can use the generated struct much as you would any other struct.  It has properties corresponding to the fields defined in the proto.  You can provide values for those properties in the initializer as well:

```
var foo = Project_Basics_Foo(id: 12)
foo.label = "Excellent"
foo.alternates = ["Good", "Better", "Best"]
```

The generated struct also includes standard definitions of hashValue, equality, and other basic utility methods:

```
if foo.isEmpty {
    // Initialize foo
}

var foos = Set<Project_Basics_Foo>()
foos.insert(foo)
```

You can serialize the object to a compact binary protobuf format or a legible JSON format:

```
print(try foo.serializeJSON())
network.write(try foo.serializeProtobuf())
```

(Note that serialization can fail if the objects contain data that cannot be represented in the target serialization.  Currently, these failures can only occur if your proto is taking advantage of the proto3 well-known Timestamp, Duration, or Any types which impose additional restrictions on the range and type of data.)

Conversely, if you have a string containing a JSON or protobuf serialized form, you can convert it back into an object using the generated initializers:

```
let foo1 = try Project_Basics_Foo(json: inputString)
let foo2 = try Project_Basics_Foo(protobuf: inputBytes)
```

## Customizing the generated structs

You can customize the generated structs by using Swift extensions.

Most obviously, you can add new methods as necessary:

```
extension Project_Basics_Foo {
   mutating func invert() {
      id = 1000 - id
      label = "Inverted " + label
   }
}
```

For very specialized applications, you can also override the generated methods in this way.  For example, if you want to change how the `hashValue` property is computed, you can redefine it as follows:

```
extension Project_Basics_Foo {
   // I only want to hash based on the id.
   var hashValue: Int { return Int(id) }
}
```

Note that the hashValue property generated by the compiler is actually called `_protoc_generated_hashValue`, so you can still access the generated version even with the override.  Similarly, you can override other methods:
* hashValue property: as described above
* customMirror property: alter how mirrors are constructed
* debugDescription property: alter the text form shown when debugging
* isEmpty test: used to identify "empty" or "unchanged" objects
* isEqualTo(other:) test: Used by ==
* serializeJSON() method: JSON serialization is generated
* serializeAnyJSON() method: generates a JSON serialization of an Any object containing this type
* decodeFromJSONToken() method: decodes an object of this type from a single JSON token (ignore this if your custom JSON format does not consist of a single token)
* decodeFromJSONNull(), decodeFromJSONObject(), decodeFromJSONArray(): decode an object of this type from the corresponding JSON data

Overriding the protobuf serialization is not fully supported at this time.

To see how this is used, you might examine the ProtobufRuntime implementation of `Google_Protobuf_Duration`.  The core of that type is compiled from `duration.proto`, but the library also includes a file `Google_Protobuf_Duration_Extensions.swift` which extends the generated code with a variety of specialized behaviors.

## Generated JSON serializers

Consider the following simple proto file:
```
message Foo {
  int32 id = 1;
  string name = 2;
  int64 my_my = 3;
}
```

A typical JSON message might look like the following:
```
{
  "id": 1732789,
  "name": "Alice",
  "myMy": "1.7e3"
}
```

In particular, note that the "my_my" field name in the proto file gets translated to "myMy" in the JSON serialized form.  You can override this with a `json_name` property on fields as needed.

To decode such a message, you would use Swift code similar to the following
```
let jsonString = ... string read from somewhere ...
let f = try Foo(json: jsonString)
print("id: \(f.id)  name: \(f.name)  myMy: \(f.myMy)")
```

Similarly, you can serialize a message object in memory to a JSON string
```
let f = Foo(id: 777, name: "Bob")
let json = try f.serializeJSON()
print("json: \(json)")
// json: {"id": 777, "name": "Bob"}
```

## Ad hoc JSON Deserialization

**TODO** Example Swift code that uses the generic JSON wrapper types to parse anonymous JSON input.

## Decoding With Proto2 Extensions

(Note that extensions are a proto2 feature that is no longer supported in proto3.)

Suppose you have the following simple proto file defining a message Foo:

```
// file base.proto
package my.project;
message Foo {
   extensions 100-1000;
}
```

And suppose another file defines an extension of that message:

```
// file more.proto
package my.project;
extend Foo {
   optional int32 extra_info = 177;
}
```

As described above, protoc will create an extension object in more.pb.swift and a Swift extension that adds an `extraInfo` property to the `My_Project_Foo` struct.

You can decode a Foo message containing this extension as follows.  Note that the extension object here includes the package name and the name of the message being extended:

```
let extensions: ProtobufExtensionSet = [My_Project_Foo_extraInfo]
let m = My_Project_Foo(protobuf: data, extensions: extensions)
print(m.extraInfo)
```

If you had many extensions defined in bar.proto, you can avoid having to list them all yourself by using the preconstructed extension set included in the generated file.  Note that the name of the preconstructed set includes the package name and the name of the input file to ensure that extensions from different files do not collide:

```
let extensions = Project_Additions_More_Extensions
let m = My_Project_Foo(protobuf: data, extensions: extensions)
```

To serialize an extension value, just set the value on the message and serialize the result as usual:

```
var m = My_Project_Foo()
m.extraInfo = 12
m.serializeProtobuf()
```

## Swift Options

```
option swift_prefix=<prefix> (no default)
```

This value will be prepended to all struct, class, and enums that are
generated in the global scope.  Nested types will not have this string
added.  By default, this is generated from the package name by
converting each package element to UpperCamelCase and combining them
with underscores.  For example, the package "foo_bar.baz" would lead
to a default Swift prefix of "FooBar_Baz_".

**CAVEAT:** The option above must be recognized by protoc when
it parses the proto file.  Older versions of protoc do not recognize
this option, cannot parse it, and will not pass it to the
code generator.  You may need to patch the protoc sources in
order to use these options.  (Patching protoc involves adding
two lines to descriptor.proto and then running a shell script
to regenerate protoc's support files before recompiling.  A
standard patch file to help with this is provided as part of the
swift-protobuf-plugin project.)


# TODO

**RawMessage:** There should be a generic wrapper around the binary protobuf decode machinery that provides a way for clients to disassemble encoded messages into raw field data accessible by field tag.

**Embedded Descriptors:** There should be an option to include embedded descriptors and a standard way to access them.

**Dynamic Messages:** There should be a generic wrapper that can accept a Descriptor or Type and provide generic decoding of a message.  This will likely build on RawMessage.

**Text PB:**  There is an old text PB format that is supported by the old proto2 Java and C++ backends.  A few folks like it; it might be easy to add.


# Differences From other implementations

Google's spec for JSON serialization of Any objects requires that JSON-to-protobuf and protobuf-to-JSON transcoding of well-formed messages fail if the full type of the object contained in the Any is not available.  Google has opined that this should always occur on the JSON side, in particular, they think that JSON-to-protobuf transcoding should fail the JSON decode.  I don't like this, since this implies that JSON-to-JSON recoding will also fail in this case.  Instead, I have the reserialization fail when transcoding with insufficient type information.

This implementation fully supports JSON encoding for proto2 types. Google has not specified how this should work, so the implementation here may not fully interoperate with other implementations.  Currently, groups are handled as if they were messages.  Proto2 extensions are serialized to JSON automatically, they are deserialized from JSON if you provide the appropriate ExtensionSet when deserializing.

The protobuf serializer currently always writes all required fields in proto2 messages. This differs from the behavior of Google's C++ and Java implementations, which omit required fields that have not been set or whose value is the default.  This may change.

Unlike proto2, proto3 does not provide a standard way to tell if a field has "been set" or not.  This is standard proto3 behavior across all languages and implementations.  If you need to distinguish an empty field, you can model this in proto3 using a oneof group with a single element:
```
message Foo {
  oneof HasName {
     string name = 432;
  }
}
```
This will cause the `name` field to be generated as a Swift `Optional<String>` which will be nil if no value was provided for `name`.
