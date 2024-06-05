{
  description = ''
    `hello_world_tool` is a simple web server built with the Axum framework that serves a "Hello, World!" response to any request to the root URL ('/'). It's designed to be used by agents as a straightforward example of an Axum server setup that can be extended with additional endpoints.

## Methods

### `hello_world`

Returns a "Hello, World!" string.

#### Syntax
```rust
async fn hello_world() -> &'static str
```
#### Example
```rust
let response = hello_world().await;
println!("{}", response); // prints "Hello, World!"
```
### `main`

Sets up the Axum app with a single route and runs the server on localhost at port 3000.

#### Syntax
```rust
#[tokio::main]
async fn main() -> Result<(), anyhow::Error>
```
#### Example
```bash
cargo run
```
### `setup_server`

Sets up the Axum app with a single route and runs the server on a random available port.

#### Syntax
```rust
async fn setup_server() -> String
```
#### Example
```rust
let addr = setup_server().await;
println!("Tool listening on {}", addr);
```
### `test_hello_world`

Tests the "Hello, World!" endpoint by sending a GET request to the root URL and verifying the response status code and body.

#### Syntax
```rust
#[tokio::test]
async fn test_hello_world()
```
#### Example
```bash
cargo test
```
## Enums

None.

## Structs

None.

## Traits

None.

## Functions

### `hello_world`

[See above](#hello_world)

### `main`

[See above](#main)

### `setup_server`

[See above](#setup_server)

### `test_hello_world`

[See above](#test_hello_world)

## Macros

None.

## Errors

### `anyhow::Error`

Error type used for error handling in the `main` function.

## Dependencies

### `anyhow`

Version 1.0.86

### `axum`

Version 0.7.5

### `axum-macros`

Version 0.4.1

### `reqwest`

Version 0.12.4

### `serde`

Version 1.0.163 with feature "derive"

### `serde_json`

Version 1.0.117

### `tokio`

Version 1.38.0 with feature "full"

## License

MIT License.
  '';

  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-23.11"; };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flakebox = {
      url = "github:dpc/flakebox?rev=226d584e9a288b9a0471af08c5712e7fac6f87dc";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.fenix.follows = "fenix";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flakebox, fenix, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
        packageName = "hello_world_tool";
        flakeboxLib = flakebox.lib.${system} { };
        rustSrc = flakeboxLib.filterSubPaths {
          root = builtins.path {
            name = packageName;
            path = ./.;
          };
          paths = [ "Cargo.toml" "Cargo.lock" ".cargo" "src" packageName ];
        };

        toolchainArgs = let llvmPackages = pkgs.llvmPackages_11;
        in {
          extraRustFlags = "--cfg tokio_unstable";

          components = [ "rustc" "cargo" "clippy" "rust-analyzer" "rust-src" ];

          args = {
            nativeBuildInputs = [ ]
              ++ lib.optionals (!pkgs.stdenv.isDarwin) [ ];
          };
        } // lib.optionalAttrs pkgs.stdenv.isDarwin {
          # on Darwin newest stdenv doesn't seem to work
          # linking rocksdb
          stdenv = pkgs.clang11Stdenv;
          clang = llvmPackages.clang;
          libclang = llvmPackages.libclang.lib;
          clang-unwrapped = llvmPackages.clang-unwrapped;
        };

        # all standard toolchains provided by flakebox
        toolchainsStd = flakeboxLib.mkStdFenixToolchains toolchainArgs;

        toolchainsNative = (pkgs.lib.getAttrs [ "default" ] toolchainsStd);

        toolchainNative =
          flakeboxLib.mkFenixMultiToolchain { toolchains = toolchainsNative; };

        commonArgs = {
          buildInputs = [ pkgs.pkg-config pkgs.openssl ]
            ++ lib.optionals pkgs.stdenv.isDarwin
            [ pkgs.darwin.apple_sdk.frameworks.SystemConfiguration ];
          nativeBuildInputs = [ pkgs.pkg-config ];
        };
        outputs = (flakeboxLib.craneMultiBuild { toolchains = toolchainsStd; })
          (craneLib':
            let
              craneLib = (craneLib'.overrideArgs {
                pname = packageName;
                src = rustSrc;
              }).overrideArgs commonArgs;
            in rec {
              workspaceDeps = craneLib.buildWorkspaceDepsOnly { };
              workspaceBuild =
                craneLib.buildWorkspace { cargoArtifacts = workspaceDeps; };
              package = craneLib.buildPackageGroup {
                pname = packageName;
                packages = [ packageName ];
                mainProgram = packageName;
              };
            });
      in {
        legacyPackages = outputs;
        packages = { default = outputs.package; };
        devShells = flakeboxLib.mkShells {
          packages = [ ];
          buildInputs = commonArgs.buildInputs;
          nativeBuildInputs = [ commonArgs.nativeBuildInputs ];
          shellHook = ''
            export RUSTFLAGS="--cfg tokio_unstable"
            export RUSTDOCFLAGS="--cfg tokio_unstable"
            export RUST_LOG="info"
          '';
        };
      });
}
