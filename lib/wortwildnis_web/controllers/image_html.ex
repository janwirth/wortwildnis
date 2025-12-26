defmodule WortwildnisWeb.ImageHTML do
  use WortwildnisWeb, :html

  @doc """
  OG image template for term pages - displays term name and description.
  """
  def term(assigns) do
    ~H"""
    <body class="bg-white flex flex-col h-screen font-mono">
      <div class="grow flex flex-col items-center justify-center px-20">
        <h1 class="font-bold text-black text-[5rem] leading-[1.2] text-center mb-8">
          {@name}
        </h1>
        <%= if @description != "" do %>
          <p class="text-black text-[2rem] leading-[1.4] text-center max-w-[1000px] opacity-80">
            {@description}
          </p>
        <% end %>
      </div>
      <div class="shrink-0 pb-12 px-20">
        <div class="text-black text-[1.5rem] opacity-60">Wortwildnis</div>
      </div>
    </body>
    """
  end

  @doc """
  Fallback template when no matching template is found.
  """
  def fallback(assigns) do
    ~H"""
    <body class="bg-white flex items-center justify-center h-screen font-mono">
      <div class="text-center">
        <h1 class="font-bold text-black text-[5rem] mb-8">Wortwildnis</h1>
        <p class="text-black text-[2rem] opacity-80">Ein Wörterbuch für deutsche Begriffe</p>
      </div>
    </body>
    """
  end
end


