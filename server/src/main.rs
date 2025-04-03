use std::sync;

use rocket::futures::{SinkExt, StreamExt};
use ronkey::{ast, environment, eval::eval_program, lexer, parser};

#[macro_use]
extern crate rocket;

#[get("/")]
fn index() -> &'static str {
    "Hello, world! :)\n\n\n---\n\n\nBy jgcardelus"
}

#[get("/eval")]
fn echo(ws: ws::WebSocket) -> ws::Channel<'static> {
    ws.channel(move |mut stream| {
        Box::pin(async move {
            let environment = sync::Arc::new(sync::Mutex::new(environment::Environment::new()));

            while let Some(message) = stream.next().await {
                process_message(&mut stream, &environment, message.unwrap()).await?;
            }

            Ok(())
        })
    })
}

#[launch]
fn rocket() -> _ {
    rocket::build().mount("/", routes![index, echo])
}

async fn process_message(
    stream: &mut ws::stream::DuplexStream,
    environment: &sync::Arc<sync::Mutex<environment::Environment>>,
    message: ws::Message,
) -> Result<(), ws::result::Error> {
    let input = message.into_text()?;

    let parsed_result = parse_input(&input);

    match parsed_result {
        Ok(program) => send_evaluation_result(stream, &program, environment).await,
        Err(errors) => send_error_result(stream, errors).await,
    }
}

fn parse_input(input: &str) -> Result<ast::Program, Vec<String>> {
    let mut lexer = lexer::new(input);
    let mut parser = parser::new(&mut lexer);

    let program = parser::parse_program(&mut parser);

    if parser.errors.len() > 0 {
        Err(parser.errors)
    } else {
        Ok(program)
    }
}

async fn send_error_result(
    stream: &mut ws::stream::DuplexStream,
    errors: Vec<String>,
) -> Result<(), ws::result::Error> {
    let error_messages: Result<(), Vec<String>> = Err(errors);
    let error_messages = serde_json::to_string(&error_messages).unwrap();

    stream.send(error_messages.into()).await
}

async fn send_evaluation_result(
    stream: &mut ws::stream::DuplexStream,
    program: &ast::Program,
    environment: &sync::Arc<sync::Mutex<environment::Environment>>,
) -> Result<(), ws::result::Error> {
    let jar = eval_program(program, environment.clone());
    let result: Result<String, ()> = Ok(jar.to_string());
    let result = serde_json::to_string(&result).unwrap();

    stream.send(result.into()).await
}
