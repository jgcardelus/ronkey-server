defmodule FrontendWeb.HomeLive do
  use FrontendWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="bg-black text-white h-full w-full flex flex-col items-center justify-center text-3xl">
    	<h1>Hello, world!</h1>
    </div>
    """
  end
end
