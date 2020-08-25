# LoLa Programming Language

LoLa is a small programming language meant to be embedded into games to be programmed by the players. The compiler and runtime are implemented in Zig and C++.

## Short Example
```js
var list = [ "Hello", "World" ];
for(text in list) {
	Print(text);
}
```

You can find more examples in the [Examples](Examples/) folder.

## Why LoLa when there is *X*?
LoLa isn't meant to be your next best day-to-day scripting language. Its design is focused on embedding the language in environments where the users want/need/should write some small scripts like games or scriptable applications. In most script languages, you as a script host don't have control over the execution time of the scripts you're executing. LoLa protects you against programming errors like endless loops and such:

### Controlled Execution Environment

Every script invocation gets a limit of instructions it might execute. When either this limit is reached or the script yields for other reasons (asynchronous functions), the execution is returned to the host.

This means, you can execute the following script "in parallel" to your application main loop without blocking your application *and* without requiring complex multithreading setups:

```js
var timer = 0;
while(true) {
	Print("Script running for ", timer, " seconds.");
	timer += 1;
	Sleep(1.0);
}
```

### Native Asynchronous Design

LoLa features both synchronous and asynchronous host functions. Synchronous host function calls are short-lived and will be executed in-place. Asynchronous functions, in contrast, will be executed multiple times until they yield a value. When they don't yield a value, control will be returned to the script host.

This script will not exhaust the instruction limit, but will only increment the counter, then return control back to the host:
```js
var counter = 0;
while(true) {
	counter += 1;
	Yield();
}
```

This behaviour can be utilized to wait for certain events in the host environment, for example to react to key presses, a script could look like this:
```js
while(true) {
	var input = WaitForKey();
	if(input == " ") {
		Print("Space was pressed!");
	}
}
```

*Note that the current implementation is not thread-safe, but requires to use the limited execution for running scripts in parallel.*

### Native "RPC" Design

LoLa also allows executing multiple scripts on the same *environment*, meaning that you can easily create cross-script communications:

```js
// script a:
var buffer;
function Set(val) { buffer = val; }
function Get() { return val; }

// script b:
// GetBuffer() returns a object referencing a environment for "script a"
var buffer = GetBuffer();
buffer.Set("Hello, World!");

// script c:
// GetBuffer() returns a object referencing a environment for "script a"
var buffer = GetBuffer(); 
Print("Buffer contains: ", buffer.Get());
```

With a fitting network stack and library, this can even be utilized cross-computer.

This example implements a small chat client and server that could work with LoLa RPC capabilities:
```js
// Chat client implementation:
var server = Connect("lola-rpc://random-projects.net/chat");
if(server == void) {
	Print("Could not connect to chat server!");
	Exit(1);
}

while(true) {
	var list = server.GetMessages(GetUser());
	for(msg in list) {
		Print("< ", msg);
	}
	
	Print("> ");
	var msg = ReadLine();
	if(msg == void)
		break;
	if(msg == "")
		continue;
	server.Send(GetUser(), msg);
}
```

```js
// Chat server implementation
var messages = CreateDictionary();

function Send(user, msg)
{
	for(other in messages.GetKeys())
	{
		if(other != user) {
			var log = messages.Get(other);
			if(log != void) {
				log = log ++ [ user + ": " + msg ];
			} else {
				log = [];
			}
			messages.Set(other, log);
		}
	}
}

function GetMessages(user)
{
	var log = messages.Get(user);
	if(log != void) {
		messages.Set(user, []);
		return log;
	} else {
		return [];
	}
}
```

### Serializable State

As LoLa has no reference semantics except for objects, it is easy to understand and learn. It is also simple in its implementation and does not require a complex garbage collector or advanced programming knowledge. Each LoLa value can be serialized/deserialized into a sequence of bytes (only exception are object handles, those require some special attention), so saving the current state of a environment/vm to disk and loading it at a later point is a first-class supported use case.

This is especially useful for games where it is favourable to save your script state into a save game as well without having any drawbacks.

### Simple Error Handling

LoLa provides little to no in-language error handling, as it's not designed to be robust against user programming errors. Each error is passed to the host as a panic, so it can show the user that there was an error (like `OutOfMemory` or `TypeMismatch`).

In-language error handling is based on the dynamic typing: Functions that allow in-language error handling just return `void` instead of a actual return value or `true`/`false` for *success* or *failure*. 

This allows simple error checking like this:
```js
var string = ReadFile("demo.data");
if(string != void) {
	Print("File contained ", string);
}
```

This design decision was made with the idea in mind that most LoLa programmers won't write the next best security critical software, but just do a quick hack in game to reach their next item unlock.

## Starting Points

To get familiar with LoLa, you can check out these starting points:

- [Documentation](Documentation/README.md)
- [Examples](Examples/README.md)

When you want to contribute to the compiler, check out the following documents:

- [Source Code](src/)
- [Bison Grammar](src/library/compiler/grammar.yy)
- [Flex Tokenizer](src/library/compiler/yy.l)
- [Issue List](https://github.com/MasterQ32/LoLa-native/issues)

## Visual Studio Code Extension
If you want syntax highlighting in VSCode, you can install the [`lola-vscode`](https://github.com/MasterQ32/lola-vscode) extension.

Right now, it's not published in the gallery, so to install the extension, you have to sideload it. [See the VSCode documentation for this](https://vscode-docs.readthedocs.io/en/stable/extensions/install-extension/).

## Building

![CI](https://github.com/MasterQ32/LoLa-native/workflows/CI/badge.svg?branch=master)

**Requirements:**

Required:
- The [Zig Compiler](https://ziglang.org/) (Version 0.6.0+60ea87340 or newer)

Optional dependencies for development:
- Bison 3.2 or newer (optional)
- Flex 2.6 or newer (optional)

**Building:**

```sh
zig build
./zig-cache/bin/lola
```

**Running the test suite:**

When you change things in the compiler or VM implementation, run the test suite:

```sh
zig build test
```

This will execute all zig tests, and also runs a set of predefined tests within the [`test/`](test/) folder. These tests will verify that the compiler and language runtime behave correctly.