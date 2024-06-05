use axum::{
    extract::Json,
    routing::{get, post},
    Router,
};
use serde::{Deserialize, Serialize};
use tokio::net::TcpListener;

#[derive(Serialize, Deserialize)]
struct MathOperation {
    a: f64,
    b: f64,
}

async fn hello_world() -> &'static str {
    "Hello, World!"
}

async fn add(Json(payload): Json<MathOperation>) -> String {
    format!("{}", payload.a + payload.b)
}

async fn subtract(Json(payload): Json<MathOperation>) -> String {
    format!("{}", payload.a - payload.b)
}

async fn multiply(Json(payload): Json<MathOperation>) -> String {
    format!("{}", payload.a * payload.b)
}

async fn divide(Json(payload): Json<MathOperation>) -> String {
    if payload.b == 0.0 {
        "Division by zero is not allowed!".to_string()
    } else {
        format!("{}", payload.a / payload.b)
    }
}

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    let app = Router::new()
        .route("/", get(hello_world))
        .route("/add", post(add))
        .route("/subtract", post(subtract))
        .route("/multiply", post(multiply))
        .route("/divide", post(divide));

    let listener = TcpListener::bind("0.0.0.0:3000").await?;
    axum::serve(listener, app).await.map_err(|e| {
        println!("Server error: {}", e);
        e
    })?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::http::StatusCode;
    use reqwest::Client;

    async fn setup_server() -> String {
        let app = Router::new()
            .route("/", get(hello_world))
            .route("/add", post(add))
            .route("/subtract", post(subtract))
            .route("/multiply", post(multiply))
            .route("/divide", post(divide));
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

    #[tokio::test]
    async fn test_add() {
        let addr = setup_server().await;

        let client = Client::new();
        let res = client
            .post(format!("http://{}/add", addr))
            .json(&serde_json::json!({ "a": 2.0, "b": 3.0 }))
            .send()
            .await
            .unwrap();

        assert_eq!(res.status(), StatusCode::OK);
        assert_eq!(res.text().await.unwrap(), "5.0");
    }

    #[tokio::test]
    async fn test_subtract() {
        let addr = setup_server().await;

        let client = Client::new();
        let res = client
            .post(format!("http://{}/subtract", addr))
            .json(&serde_json::json!({ "a": 2.0, "b": 3.0 }))
            .send()
            .await
            .unwrap();

        assert_eq!(res.status(), StatusCode::OK);
        assert_eq!(res.text().await.unwrap(), "-1.0");
    }

    #[tokio::test]
    async fn test_multiply() {
        let addr = setup_server().await;

        let client = Client::new();
        let res = client
            .post(format!("http://{}/multiply", addr))
            .json(&serde_json::json!({ "a": 2.0, "b": 3.0 }))
            .send()
            .await
            .unwrap();

        assert_eq!(res.status(), StatusCode::OK);
        assert_eq!(res.text().await.unwrap(), "6.0");
    }

    #[tokio::test]
    async fn test_divide() {
        let addr = setup_server().await;

        let client = Client::new();
        let res = client
            .post(format!("http://{}/divide", addr))
            .json(&serde_json::json!({ "a": 6.0, "b": 3.0 }))
            .send()
            .await
            .unwrap();

        assert_eq!(res.status(), StatusCode::OK);
        assert_eq!(res.text().await.unwrap(), "2.0");
    }
}