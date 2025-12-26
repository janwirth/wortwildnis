defmodule WortwildnisWeb.TermLive.IndexRefactor do
  use WortwildnisWeb, :live_view

  on_mount {WortwildnisWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def handle_params(params, _uri, socket) do
    IO.puts("Handling params: #{inspect(params)}")

    mode =
      case params do
        %{"q" => q} -> {:search, q}
        %{"letter" => letter} -> {:letter, letter}
        _ -> :recent
      end

    socket = assign(socket, :mode, mode)
    {:noreply, socket}
  end

  defp mode_assigns(:recent), do: %{mode: :recent}
  defp mode_assigns({:letter, letter}), do: %{mode: :letter, letter: letter}
  defp mode_assigns({:search, query}), do: %{mode: :search, query: query}
  defp mode_assigns(:term_of_the_day), do: %{mode: :term_of_the_day}

  defp mode_assigns({:user_submitted_terms, user_id}),
    do: %{mode: :user_submitted_terms, user_id: user_id}

  defp mode_assigns({:user_reacted_terms, user_id}),
    do: %{mode: :user_reacted_terms, user_id: user_id}

  # handling updates - this is required for all parents that have a list component child
  @impl true
  def handle_info({:refresh_term, id}, socket) do
    IO.puts("Updating term: #{id}")

    term =
      WortwildnisWeb.LiveView.TermHelpers.get_term_with_loads(id, socket.assigns.current_user)

    send_update(WortwildnisWeb.TermLive.IndexRefactor.List, id: "list-recent", update_term: term)

    send_update(WortwildnisWeb.TermLive.IndexRefactor.List,
      id: "list-term-of-the-day",
      update_term: term
    )

    send_update(WortwildnisWeb.TermLive.IndexRefactor.List,
      id: "list-letter-J",
      update_term: term
    )

    send_update(WortwildnisWeb.TermLive.IndexRefactor.List, id: "list-search", update_term: term)

    send_update(WortwildnisWeb.TermLive.IndexRefactor.List,
      id: "list-current-user-submitted-terms",
      update_term: term
    )

    send_update(WortwildnisWeb.TermLive.IndexRefactor.List,
      id: "list-current-user-reacted-terms",
      update_term: term
    )

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      socket={@socket}
      search_input_value={assigns[:search_input_value]}
    >
      <div class="flex flex-col gap-12">
        <h1>LETTER J</h1>
        <.live_component
          module={WortwildnisWeb.TermLive.IndexRefactor.List}
          id="list-letter-J"
          {mode_assigns({:letter, "J"})}
          current_user={@current_user}
        />
        <h1>SEARCH "JETZT"</h1>
        <.live_component
          module={WortwildnisWeb.TermLive.IndexRefactor.List}
          id="list-search"
          {mode_assigns({:search, "Jetzt"})}
          current_user={@current_user}
        />
        <h1>CURRENT USER SUBMITTED TERMS</h1>
        <.live_component
          module={WortwildnisWeb.TermLive.IndexRefactor.List}
          id="list-current-user-submitted-terms"
          {mode_assigns({:user_submitted_terms, @current_user.id})}
          current_user={@current_user}
        />
        <h1>Terms of the day</h1>
        <.live_component
          module={WortwildnisWeb.TermLive.IndexRefactor.List}
          id="list-term-of-the-day"
          {mode_assigns(:term_of_the_day)}
          current_user={@current_user}
        />

        <h1>CURRENT USER REACTED TERMS</h1>
        <.live_component
          module={WortwildnisWeb.TermLive.IndexRefactor.List}
          id="list-current-user-reacted-terms"
          {mode_assigns({:user_reacted_terms, @current_user.id})}
          current_user={@current_user}
        />
        <h1>RECENT</h1>

        <.live_component
          module={WortwildnisWeb.TermLive.IndexRefactor.List}
          id="list-recent"
          {mode_assigns(:recent)}
          current_user={@current_user}
        />
        <!--
      -->
      </div>
    </Layouts.app>
    """
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
