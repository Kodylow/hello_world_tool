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

#[cfg(test)]
mod tests {
    use super::*;
    use axum::http::StatusCode;
    use reqwest::Client;

    async fn setup_server() -> String {
        let app = Router::new().route("/", get(hello_world));
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap().to_string();
        println!("Tool listening on {}", addr);
        tokio::spawn(async move {
            axum::serve(listener, app).await.unwrap();
        });
        addr
    }

    #[tokio::test]
    async fn test_hello_world() {
        let addr = setup_server().await;

        let client = Client::new();
        let res = client.get(format!("http://{}", addr)).send().await.unwrap();

        assert_eq!(res.status(), StatusCode::OK);
        assert_eq!(res.text().await.unwrap(), "Hello, World!");
    }
}
