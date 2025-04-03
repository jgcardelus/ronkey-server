defmodule FrontendWeb.HomeLive do
  use FrontendWeb, :live_view

  # Define WebSocket client module
  defmodule WSClient do
    use WebSockex

    def start_link(url, parent) do
      WebSockex.start_link(url, __MODULE__, %{parent: parent})
    end

    def handle_frame({:text, msg}, state) do
      send(state.parent, {:ws_messages, msg})
      {:ok, state}
    end

    def send_message(client, message) do
      WebSockex.send_frame(client, {:text, message})
    end
  end

  defmodule Message do
    defstruct sender: nil,
              is_ok?: true,
              content: nil

    def you(message) do
      %Message{
        sender: :you,
        is_ok?: true,
        content: message
      }
    end

    def ok(eval) do
      %Message{
        sender: :ronkey,
        is_ok?: true,
        content: eval
      }
    end

    def err(eval) do
      %Message{
        sender: :ronkey,
        is_ok?: false,
        content: eval
      }
    end
  end

  def mount(_params, _session, socket) do
    socket =
      case WSClient.start_link("ws://rocket_server:8000/eval", self()) do
        {:ok, ws_client} ->
          socket
          |> assign(ws_client: ws_client)
          |> reset()

        {:error, error} ->
          error |> IO.inspect()

          socket
          |> assign(error: true)
      end

    {:ok, socket}
  end

  defp reset(socket) do
    socket
    |> assign_input_form()
    |> assign(has_messages: false)
    |> stream(:messages, [],
      dom_id: fn _messages -> "messages_#{System.unique_integer([:positive])}" end,
      reset: true
    )
  end

  def render(%{error: true} = assigns) do
    ~H"""
    <div class="bg-black text-white font-serif w-full h-full flex flex-col items-center justify-center overflow-auto">
      <div class="max-h-full h-full w-full md:max-h-[800px] max-w-[500px] flex flex-col overflow-auto">
        <div class="flex flex-col gap-8 max-h-full h-full overflow-auto">
          <div class="flex flex-col gap-4 mt-24">
            <h1 class="text-4xl font-bold text-white ">🙈</h1>
            <h1 class="text-4xl font-bold text-white ">
              Oh no! The Ronkey server is down.
            </h1>
            <p class="text-lg">
              This is probable because someone tried a very complicated query... this things happen.
            </p>
            <p class="text-lg">The system is rebooting and it'll be back online in a few moments.</p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def render(%{has_messages: false} = assigns) do
    ~H"""
    <.container form={@form}>
      <div class="p-4 flex flex-col gap-8">
        <.ronkey_header />
      </div>
    </.container>
    """
  end

  def render(assigns) do
    ~H"""
    <.container form={@form}>
      <div class="h-full flex flex-col overflow-auto">
        <div class="p-4 border-b border-gray-600 sticky top-0 bg-black z-10 flex flex-row justify-between items-center">
          <p class="text-lg text-bold">The Ronkey REPL — by jgcardelus</p>
          <div phx-click="reset" class="cursor-pointer select-none">
            <p class="text-lg">🐒</p>
          </div>
        </div>
        <div id="messages" phx-update="stream" class="w-full p-4 flex flex-col gap-4">
          <.message :for={{id, message} <- @streams.messages} message={message} id={id} />
        </div>
      </div>
    </.container>
    """
  end

  defp container(assigns) do
    ~H"""
    <div class="bg-black text-white font-serif w-full h-full flex flex-col items-center justify-center overflow-auto">
      <div class="max-h-full h-full w-full md:max-h-[800px] max-w-[500px] flex flex-col overflow-auto">
        <div class="flex flex-col gap-8 max-h-full h-full overflow-auto">
          {render_slot(@inner_block)}
        </div>
        <.content form={@form} />
      </div>
    </div>
    """
  end

  defp examples(assigns) do
    ~H"""
    <div class={["flex flex-row gap-2 z-10", @class]}>
      <.example
        title="Factorial"
        example="let fact = fn (x) { if (x == 0) { return 1; } else { return fact(x - 1) * x;}}; fact(5);"
      />
      <.example
        title="Fibonacci"
        example="let fib = fn (x) { if (x <= 1) { return x; } else { return fib(x - 1) + fib(x - 2); }}; fib(6);"
      />
      <.example
        title="Max"
        example="let max = fn (a, b) { if (a > b) { return a; } else { return b; }}; max(10, 5);"
      />
      <.example
        title="Min"
        example="let min = fn (a, b) { if (a < b) { return a; } else { return b; }}; min(3, 7);"
      />
    </div>
    """
  end

  defp content(assigns) do
    ~H"""
    <div class="sticky bottom-0 bg-gray-900 border-t border-gray-600 z-1 p-4 flex flex-col gap-4">
      <div class="flex flex-row gap-4 items-center overflow-x-auto">
        <div class="sticky left-0 z-0">
          <p class="text-nowrap">Ready made examples</p>
        </div>
        <.examples class="bg-gray-900" />
      </div>
      <.ronkey_input form={@form} />
    </div>
    """
  end

  defp example(assigns) do
    ~H"""
    <div
      class="p-2 bg-gray-800 rounded-md z-10 cursor-pointer"
      phx-click={
        JS.push("save",
          value: %{
            "input" => %{
              "input" => @example
            }
          }
        )
      }
    >
      <p>{@title}</p>
    </div>
    """
  end

  defp ronkey_input(assigns) do
    ~H"""
    <div class="flex flex-col gap-2 w-full ">
      <.form
        for={@form}
        phx-change="validate"
        phx-submit="save"
        class="flex flex-row gap-2 w-full items-center justify-between"
      >
        <input
          type="text"
          name={@form["input"].name}
          value={@form["input"].value}
          placeholder="Type the code, press enter to evaluate"
          class="ring-0 border-gray-600 bg-black p-2 text-gray-200 rounded-md w-full focus:ring-0 focus:border-gray-500"
        />
        <button class="bg-white rounded-md text-black p-2 phx-submit-loading:opacity-50">
          <.icon name="hero-paper-airplane" class="h-5 w-5 " />
        </button>
      </.form>
      <div class="flex flex-col gap-1">
        <p class="text-xs">
          Ronkey supports integers, bools, if, let, return and fn expressions
        </p>
      </div>
    </div>
    """
  end

  defp ronkey_header(assigns) do
    ~H"""
    <.intro />
    <.language_showcase />
    <.more />
    <p class="text-xl text-gray-400">
      <a class="underline" href="https://github.com/jgcardelus/ronkey">Source code</a>
    </p>
    """
  end

  defp intro(assigns) do
    ~H"""
    <div class="flex flex-col gap-2 mt-24">
      <h1 class="text-4xl font-bold text-white ">🐒</h1>
      <h1 class="text-4xl font-bold text-white ">
        Welcome to the Ronkey REPL
      </h1>
    </div>
    <p class="text-xl text-white font-bold">
      Click on a ready made example to get started (or type some code).
    </p>
    <.examples class="bg-black" />
    <p class="text-xl text-gray-400">
      Ronkey is an interpreter  for the
      <a class="underline" href="https://interpreterbook.com/">
        Monkey Programming Language by Thorsten Ball
      </a>
      written in Rust.
    </p>
    <p class="text-xl text-gray-400">
      Made by Jorge Gonzalez Cardelus.
      <a class="underline" href="https://www.linkedin.com/in/jgcardelus/">Check me out :)</a>
    </p>
    """
  end

  defp expandable(assigns) do
    ~H"""
    <div class="flex flex-col gap-4">
      <div
        class="flex flex-row gap-2 items-center p-2 bg-gray-900 rounded-md cursor-pointer"
        phx-click={JS.toggle_class("hidden", to: "##{@id}")}
      >
        <.icon name="hero-plus" class="h-5 w-5 transition-transform duration-300" />
        <p class="text-xl">
          {@title}
        </p>
      </div>
      <div id={@id} class="hidden flex flex-col gap-8 p-2 bg-gray-900 rounded-md ">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  defp more(assigns) do
    ~H"""
    <.expandable id="more-info" title="More">
      <p class="text-xl text-white">
        What's a REPL? Read, eval, print, loop. Basically a Jupyter Notebook.
      </p>
    </.expandable>
    """
  end

  defp language_showcase(assigns) do
    ~H"""
    <.expandable id="syntax-examples" title="Ronkey syntax">
      <.showcase title="Basic arithmetic" examples={["1 * 2 + 2; // 4", "-(1 + 2) + 3 * 4; // 9"]} />
      <.showcase title="If Statements" examples={["if (a > b) { a } else { b }"]} />
      <.showcase title="Variables" examples={["let a = 1;", "let c = if (a > b) { a } else { b };"]} />
      <.showcase
        title="Functions"
        examples={["let add = fn(a, b) { a + b };", "let adder = fn (b) { fn (c) { b + c } };"]}
      />
    </.expandable>
    """
  end

  defp showcase(assigns) do
    ~H"""
    <div class="flex flex-col gap-2">
      <p class="text-lg ">{@title}</p>
      <div class="p-1 px-2 w-full max-w-full overflow-x-auto bg-gray-800 rounded-md border flex flex-col gap-1">
        <p :for={example <- @examples} class="font-mono text-lg text-nowrap">{example}</p>
      </div>
    </div>
    """
  end

  defp message(%{message: %{sender: :you}} = assigns) do
    ~H"""
    <div class="p-4 font-mono text-white w-full max-w-full overflow-x-auto" id={@id}>
      <p class="text-nowrap">{@message.content}</p>
    </div>
    """
  end

  defp message(%{message: %{sender: :ronkey, is_ok?: true}} = assigns) do
    ~H"""
    <div
      class="p-4 font-mono text-white border rounded-md bg-gray-800 w-full max-w-full overflow-x-auto"
      id={@id}
    >
      <p class="text-nowrap">{@message.content}</p>
    </div>
    """
  end

  defp message(%{message: %{sender: :ronkey, is_ok?: false}} = assigns) do
    ~H"""
    <div
      class="p-4 font-mono text-red-500 border rounded-md bg-gray-800 w-full max-w-full overflow-x-auto"
      id={@id}
    >
      <p class="text-nowrap">{@message.content}</p>
    </div>
    """
  end

  def handle_event("validate", %{"input" => input}, socket) do
    socket = assign_input_form(socket, input)
    {:noreply, socket}
  end

  def handle_event("save", %{"input" => input}, socket) do
    input =
      Map.get(input, "input")
      |> String.trim()
      |> IO.inspect()

    socket =
      if input != "" do
        socket
        |> send_message(input)
      else
        socket
      end

    {:noreply, socket}
  end

  def send_message(socket, "alba") do
    socket
    |> assign_input_form(%{})
    |> assign(has_messages: true)
    |> stream_insert(:messages, Message.you("alba"))
    |> stream_insert(:messages, Message.ok("💐"))
  end

  def send_message(socket, message) do
    WSClient.send_message(socket.assigns.ws_client, message)

    socket
    |> assign_input_form(%{})
    |> assign(has_messages: true)
    |> stream_insert(:messages, Message.you(message))
  end

  def handle_event("reset", _params, socket) do
    socket = reset(socket)

    {:noreply, socket}
  end

  def handle_info({:ws_messages, msg}, socket) do
    socket =
      case Jason.decode(msg) do
        {:ok, %{"Ok" => eval}} -> handle_message(socket, Message.ok(eval))
        {:ok, %{"Err" => eval}} -> handle_message(socket, Message.err(eval))
        _ -> socket
      end

    {:noreply, socket}
  end

  defp handle_message(socket, message) do
    socket
    |> stream_insert(:messages, message)
  end

  def assign_input_form(socket, data \\ %{}) do
    form = to_form(data, as: "input")

    socket
    |> assign(:form, form)
  end
end
