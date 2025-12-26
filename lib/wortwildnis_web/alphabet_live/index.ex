defmodule WortwildnisWeb.AlphabetLive.Index do
  use WortwildnisWeb, :live_view

  @alphabet ~w(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-4">
        <h1 class="text-3xl font-bold">Alphabet</h1>
        <div class="flex flex-wrap gap-2">
          <.link
            :for={letter <- @alphabet}
            navigate={~p"/alphabetisch/#{String.downcase(letter)}"}
            class={[
              "py-2 px-2 -mx-2 hover:opacity-75 transition-opacity w-12 text-lg font-bold",
              ""
            ]}
          >
            {letter}
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    seo_item = %{
      title: "Alphabet",
      description: "Durchsuchen Sie das Wörterbuch alphabetisch",
      noindex: true
    }

    {:ok,
     socket
     |> assign(:page_title, "Alphabet")
     |> assign(:alphabet, @alphabet)
     |> assign_new(:current_user, fn -> nil end)
     |> SEO.assign(seo_item)
     |> assign(:seo_temporary, true)}
  end

  @impl true
  def handle_event("random_term", _params, socket) do
    case Ash.read_one(Wortwildnis.Dictionary.Term,
           action: :random,
           actor: socket.assigns.current_user
         ) do
      {:ok, term} when not is_nil(term) ->
        {:noreply, push_navigate(socket, to: ~p"/definition/#{term.name}")}

      _ ->
        {:noreply, put_flash(socket, :error, "Kein Begriff gefunden")}
    end
  end
end
