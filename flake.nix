{
  description = ''
    `hello_world_tool` is a simple web server built with Axum, designed to serve a basic "Hello, World!" response. This crate provides an easy-to-use API for creating and running a simple HTTP server.

**API Documentation**

### `hello_world_tool::main`

The `main` function is the entry point of the server. It sets up an Axum router with a single route for the root URL (`/`) and starts the server on `localhost:3000`.

```rust
async fn main() -> Result<(), anyhow::Error>
```

### `hello_world_tool::hello_world`

The `hello_world` function returns a static string "Hello, World!".

```rust
async fn hello_world() -> &'static str
```

### `hello_world_tool::setup_server`

The `setup_server` function sets up an Axum router with a single route for the root URL (`/`) and starts the server on a random available port.

```rust
async fn setup_server() -> String
```

**Examples**

### Running the Server

To run the server, clone the repository, navigate to the project directory, and run `cargo run`. The server will start on `localhost:3000`.

### Testing the Server

The `test_hello_world` function creates a test server and sends a GET request to the root URL (`/`). It asserts that the response status is OK (200) and the response body is "Hello, World!".

```rust
#[tokio::test]
async fn test_hello_world() {
    let addr = setup_server().await;

    let client = reqwest::Client::new();
    let res = client.get(format!("http://{}", addr)).send().await.unwrap();

    assert_eq!(res.status(), StatusCode::OK);
    assert_eq!(res.text().await.unwrap(), "Hello, World!");
}
```

### Return Types and Errors

The `main` function returns a `Result` of type `()`, which means it returns a success value `()` or an error of type `anyhow::Error`.
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
