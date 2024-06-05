{
  description = ''
    Here is the in-depth crate description including full API documentation:

**hello_world_tool**

An agent tool for a hello world Axum server

**Overview**

The `hello_world_tool` crate provides a simple web server implemented using the Axum framework, designed to serve a basic "Hello, World!" response. It is intended for use by agents who require a straightforward example of an Axum server setup that they can add endpoints to.

**API**

### Functions

#### `hello_world`

```rust
async fn hello_world() -> &'static str
```

Returns a static string "Hello, World!".

### Structs

#### `Router`

```rust
use axum::{routing::get, Router};
```

A router instance for defining routes.

### Methods

#### `route`

```rust
let app = Router::new().route("/", get(hello_world));
```

Adds a route to the router. In this case, a GET request to "/" returns the result of `hello_world()`.

#### `serve`

```rust
axum::serve(listener, app).await.map_err(|e| {
    println!("Server error: {}", e);
    e
})?;
```

Serves the application on a TCP listener. In this case, it listens on `0.0.0.0:3000`.

### Tests

#### `setup_server`

```rust
async fn setup_server() -> String
```

Sets up a test server on a random available port.

#### `test_hello_world`

```rust
#[tokio::test]
async fn test_hello_world() {
    let addr = setup_server().await;

    let client = Client::new();
    let res = client.get(format!("http://{}", addr)).send().await.unwrap();

    assert_eq!(res.status(), StatusCode::OK);
    assert_eq!(res.text().await.unwrap(), "Hello, World!");
}
```

A test that verifies the "Hello, World!" response.

### Dependencies

* `anyhow`: Error handling library (version 1.0.86)
* `axum`: Web framework (version 0.7.5)
* `axum-macros`: Macros for Axum (version 0.4.1)
* `reqwest`: HTTP client (version 0.12.4)
* `serde`: Serialization library (version 1.0.163 with `derive` feature)
* `serde_json`: JSON serialization library (version 1.0.117)
* `tokio`: Async runtime (version 1.38.0 with `full` feature)

### License

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
