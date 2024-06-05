{
  description = ''
    Here is the crate description with full API documentation:

`hello_world_tool` is a simple web server implemented using the Axum framework. It is designed to serve a basic "Hello, World!" response and is intended for use by agents who require a straightforward example of an Axum server setup that they can add endpoints to.

## API Documentation

### `hello_world_tool`

The `hello_world_tool` crate provides a single function: `hello_world`.

#### `hello_world`

Returns a `&'static str` containing the string "Hello, World!".

##### Example
```rust
use hello_world_tool::hello_world;

let hello = hello_world();
assert_eq!(hello, "Hello, World!");
```

### `hello_world_tool::main`

The `main` function is the entry point of the `hello_world_tool` application. It sets up an Axum server to listen on port 3000 and respond with "Hello, World!" to any requests to the root URL (`/`).

##### Example
```rust
use hello_world_tool::main;

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    main().await
}
```

### `hello_world_tool::setup_server`

Sets up an Axum server to listen on a random available port on localhost and returns the address of the server.

##### Example
```rust
use hello_world_tool::setup_server;

#[tokio::test]
async fn test_hello_world() {
    let addr = setup_server().await;
    let client = reqwest::Client::new();
    let res = client.get(format!("http://{}", addr)).send().await.unwrap();
    assert_eq!(res.status(), 200);
    assert_eq!(res.text().await.unwrap(), "Hello, World!");
}
```

### `hello_world_tool::tests`

The `tests` module provides a single test function: `test_hello_world`.

#### `test_hello_world`

Tests that the `hello_world` function returns "Hello, World!".

##### Example
```rust
use hello_world_tool::tests;

#[tokio::test]
async fn test_hello_world() {
    tests::test_hello_world().await;
}
```

## Configuration

### `Cargo.toml`

The `hello_world_tool` crate depends on the following crates:

* `anyhow` (version 1.0.86)
* `axum` (version 0.7.5)
* `axum-macros` (version 0.4.1)
* `reqwest` (version 0.12.4)
* `serde` (version 1.0.163 with feature "derive")
* `serde_json` (version 1.0.117)
* `tokio` (version 1.38.0 with feature "full")
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
