use axum::{routing::get, Router};
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    // Define the app with a single route
    let app = Router::new().route("/", get(hello_world));
    let listener = TcpListener::bind("0.0.0.0:3000").await?;
    // Run the server on localhost at port 3000
    axum::serve(listener, app).await.map_err(|e| {
        println!("Server error: {}", e);
        e
    })?;
    Ok(())
}

async fn hello_world() -> &'static str {
    "Hello, World!"
}
