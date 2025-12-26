defmodule WortwildnisWeb.TermLive.Index do
  use WortwildnisWeb, :live_view

  on_mount {WortwildnisWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      socket={@socket}
      search_input_value={assigns[:search_input_value]}
    >
      <div class="space-y-4">
        <!--

      {inspect(assigns.mode)}
      -->

        {render_view(assigns, @mode)}
      </div>
    </Layouts.app>
    """
  end

  defp render_view(assigns, {:search, query}) do
    assigns = assign(assigns, :query, query)

    ~H"""
    <div class="flex flex-col gap-6">
      <h1 class="text-xl  font-bold">Definition: {@query}</h1>
      <.live_component
        module={WortwildnisWeb.TermLive.IndexRefactor.List}
        id="list-search"
        mode={:search}
        query={@query}
        current_user={@current_user}
      />
    </div>
    """
  end

  defp render_view(assigns, {:letter, letter}) do
    assigns = assign(assigns, :letter, letter)

    ~H"""
    <div class="flex flex-col gap-6">
      <h1 class="text-xl  font-bold">Begriffe die mit {String.upcase(@letter)} beginnen</h1>
      <.live_component
        module={WortwildnisWeb.TermLive.IndexRefactor.List}
        id="list-letter"
        mode={:letter}
        letter={@letter}
        current_user={@current_user}
      />
    </div>
    """
  end

  defp render_view(assigns, {:profile, profile_id}) do
    assigns = assign(assigns, :profile_id, profile_id)

    ~H"""
    <div class="flex flex-col gap-12">
      <.live_component
        module={WortwildnisWeb.ProfileLive.Index}
        id="profile-index"
        profile_id={@profile_id}
        current_user={@current_user}
      />
      <div>
        <h2 class="text-xl  font-bold mb-4">Meine Begriffe</h2>
        <.live_component
          module={WortwildnisWeb.TermLive.IndexRefactor.List}
          id="list-profile"
          mode={:user_submitted_terms}
          user_id={@profile_id}
          current_user={@current_user}
        />
      </div>
      <div>
        <h2 class="text-xl  font-bold mb-4">Meine Reaktionen</h2>
        <.live_component
          module={WortwildnisWeb.TermLive.IndexRefactor.List}
          id="list-profile-reactions"
          mode={:user_reacted_terms}
          user_id={@profile_id}
          current_user={@current_user}
        />
      </div>
    </div>
    """
  end

  defp render_view(assigns, :home) do
    ~H"""
    <div class="flex flex-col gap-6">
      <h1 class="text-2xl  font-bold opacity-80">Wortwildnis - Deutsche Umgangssprache & Slang</h1>
      <p class="text-base ">
        Wortwildnis ist ein urbanes Wörterbuch für moderne Umgangssprache und digitale Begriffe. Von Nutzer:innen gesammelt und verständlich erklärt.
      </p>
      <.live_component
        module={WortwildnisWeb.TermLive.IndexRefactor.List}
        id="list-term-of-the-day"
        mode={:term_of_the_day}
        current_user={@current_user}
      />
      <div class="flex gap-2">
        <h2 class="text-xl  font-bold">Beliebt</h2>
        <.link
          href={~p"/neu"}
          class="text-base font-bold  text-xl cursor-pointer text-blue-500 hover:text-blue-600"
        >
          Neu
        </.link>
      </div>
      <.live_component
        module={WortwildnisWeb.TermLive.IndexRefactor.List}
        id="list-hot"
        mode={:hot}
        current_user={@current_user}
      />
    </div>
    """
  end

  defp render_view(assigns, :recent) do
    ~H"""
    <div class="flex flex-col gap-6">
      <h1 class="text-2xl  font-bold">Wortwildnis - Deutsche Umgangssprache</h1>
      <.live_component
        module={WortwildnisWeb.TermLive.IndexRefactor.List}
        id="list-term-of-the-day"
        mode={:term_of_the_day}
        current_user={@current_user}
      />
      <div class="flex gap-2">
        <.link
          href={~p"/"}
          class="text-base font-bold  text-xl cursor-pointer text-blue-500 hover:text-blue-600"
        >
          Beliebt
        </.link>
        <h2 class="text-xl  font-bold">Neu</h2>
      </div>
      <.live_component
        module={WortwildnisWeb.TermLive.IndexRefactor.List}
        id="list-recent"
        mode={:recent}
        current_user={@current_user}
      />
    </div>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    # Subscribe to term translation updates and reaction changes
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Wortwildnis.PubSub, "terms:translated")
      Phoenix.PubSub.subscribe(Wortwildnis.PubSub, "terms:destroyed")
      Phoenix.PubSub.subscribe(Wortwildnis.PubSub, "terms:contained_terms_found")
      Phoenix.PubSub.subscribe(Wortwildnis.PubSub, "reactions:changed")
    end

    mode = determine_mode(params, socket)
    socket = assign_mode(socket, mode)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # Ensure subscription is active (in case of process reuse)
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Wortwildnis.PubSub, "terms:translated")
      Phoenix.PubSub.subscribe(Wortwildnis.PubSub, "terms:destroyed")
      Phoenix.PubSub.subscribe(Wortwildnis.PubSub, "terms:contained_terms_found")
      Phoenix.PubSub.subscribe(Wortwildnis.PubSub, "reactions:changed")
    end

    mode = determine_mode(params, socket)
    socket = assign_mode(socket, mode)

    {:noreply, socket}
  end

  defp determine_mode(params, socket) do
    IO.puts("Determining mode: #{inspect(params)} #{inspect(socket.assigns.live_action)}")

    cond do
      socket.assigns.live_action == :profile ->
        {:profile, socket.assigns.current_user}

      socket.assigns.live_action == :recent ->
        :recent

      params["q"] && params["q"] != "" ->
        {:search, params["q"]}

      params["letter"] ->
        {:letter, String.downcase(params["letter"])}

      params["profile_id"] ->
        {:profile, params["profile_id"]}

      true ->
        :home
    end
  end

  defp assign_mode(socket, mode) do
    search_input_value =
      case mode do
        {:search, query} -> query
        _ -> ""
      end

    # Assign SEO items and page titles for all modes
    {seo_item, page_title} =
      case mode do
        :home ->
          {
            %{
              title: "Das Deutsche Urban Dictionary",
              description: "Wortwildnis - Ein Wörterbuch für deutsche Begriffe und Slang"
            },
            "Startseite"
          }

        :recent ->
          {
            %{
              title: "Das Deutsche Urban Dictionary",
              description: "Wortwildnis - Ein Wörterbuch für deutsche Begriffe und Slang",
              noindex: true
            },
            "Neue Begriffe"
          }

        {:letter, letter} ->
          {
            %{
              title: "Begriffe mit #{String.upcase(letter)}",
              description:
                "Alphabetische Liste aller Begriffe, die mit #{String.upcase(letter)} beginnen",
              noindex: true
            },
            "Begriffe mit #{String.upcase(letter)}"
          }

        {:profile, _profile_id} ->
          # Profile SEO - will be updated when user info is available
          {
            %{
              title: "Profil",
              description: "Benutzerprofil",
              noindex: true
            },
            "Profil"
          }

        {:search, query} ->
          {results, _total_count} =
            Wortwildnis.Dictionary.Term
            |> Ash.Query.for_read(:search, q: query)
            |> Ash.Query.limit(1)
            |> WortwildnisWeb.TermLive.IndexRefactor.LoadHelpers.read_terms_with_count(nil, 1)

          case results do
            [first_hit] ->
              # Only noindex if the first result has no reactions
              has_reactions = first_hit.reactions && length(first_hit.reactions) > 0

              {
                %{
                  title: first_hit.name,
                  description: first_hit.description,
                  noindex: !has_reactions
                },
                first_hit.name
              }

            _ ->
              {
                %{
                  title: "Definition: #{query}",
                  description: "Suche nach Begriffen",
                  noindex: true
                },
                "Definition: #{query}"
              }
          end
      end

    socket
    |> assign(:mode, mode)
    |> assign(:search_input_value, search_input_value)
    |> assign(:page_title, page_title)
    |> SEO.assign(seo_item)
    |> assign(:seo_temporary, true)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    term = Ash.get!(Wortwildnis.Dictionary.Term, id, actor: socket.assigns.current_user)
    Ash.destroy!(term, action: :destroy, actor: socket.assigns.current_user)

    visible_list_ids = get_visible_list_ids(socket.assigns.mode)

    Enum.each(visible_list_ids, fn list_id ->
      send_update(WortwildnisWeb.TermLive.IndexRefactor.List, id: list_id, delete_term_id: id)
    end)

    {:noreply, socket |> put_flash(:info, "Begriff gelöscht")}
  end

  @impl true
  def handle_event("search", %{"search" => %{"q" => ""}}, socket) do
    # Clear search when input is empty
    socket =
      socket
      |> assign_mode(:home)
      |> push_patch(to: ~p"/")

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => %{"q" => q}}, socket) when is_binary(q) do
    q = String.trim(q)

    socket =
      if q == "" do
        socket
        |> assign_mode(:home)
        |> push_patch(to: ~p"/")
      else
        socket
        |> assign_mode({:search, q})
        |> push_patch(to: ~p"/definition/#{q}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"q" => ""}, socket) do
    # Handle direct q parameter (for backwards compatibility)
    socket =
      socket
      |> assign_mode(:home)
      |> push_patch(to: ~p"/")

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) when is_binary(q) do
    # Handle direct q parameter (for backwards compatibility)
    q = String.trim(q)

    socket =
      if q == "" do
        socket
        |> assign_mode(:home)
        |> push_patch(to: ~p"/")
      else
        socket
        |> assign_mode({:search, q})
        |> push_patch(to: ~p"/definition/#{q}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", _params, socket) do
    {:noreply, socket}
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

  @impl true
  def handle_info({:put_flash, kind, message}, socket) do
    {:noreply, put_flash(socket, kind, message)}
  end

  @impl true
  def handle_info({:user_updated, updated_user, flash_message}, socket) do
    socket =
      socket
      |> assign(:current_user, updated_user)
      |> put_flash(:info, flash_message)

    # Update the profile component with the new user
    send_update(WortwildnisWeb.ProfileLive.Index, id: "profile-index", current_user: updated_user)

    {:noreply, socket}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "translate", payload: notification}, socket) do
    term_id = notification.data.id
    IO.puts("Term translated via PubSub: #{term_id}")
    update_visible_lists(socket, term_id, :update_term)
    {:noreply, socket}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{event: "find_contained_terms", payload: notification},
        socket
      ) do
    term_id = notification.data.id
    IO.puts("Term contained_terms_found via PubSub: #{term_id}")
    update_visible_lists(socket, term_id, :update_term)
    {:noreply, socket}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "destroyed", payload: notification}, socket) do
    term_id = notification.data.id
    IO.puts("Term destroyed via PubSub: #{term_id}")
    update_visible_lists(socket, term_id, :update_term)
    {:noreply, socket}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: event, payload: notification}, socket)
      when event in ["react", "destroy"] do
    # Handle PubSub broadcast from Ash when a reaction is created or destroyed
    # notification.data is the Reaction, we need to refresh the associated Term
    term_id = notification.data.term_id
    IO.puts("Reaction #{event} via PubSub for term: #{term_id}")
    update_visible_lists(socket, term_id, :update_term)
    {:noreply, socket}
  end

  # Helper function to get visible list IDs based on current mode
  defp get_visible_list_ids(mode) do
    case mode do
      :home ->
        ["list-term-of-the-day", "list-hot"]

      :recent ->
        ["list-term-of-the-day", "list-recent"]

      {:search, _query} ->
        ["list-search"]

      {:letter, _letter} ->
        ["list-letter"]

      {:profile, _profile_id} ->
        ["list-profile", "list-profile-reactions"]

      _ ->
        []
    end
  end

  # Helper function to update only visible list components
  defp update_visible_lists(socket, term_id, action) do
    term =
      WortwildnisWeb.LiveView.TermHelpers.get_term_with_loads(
        term_id,
        socket.assigns.current_user
      )

    visible_list_ids = get_visible_list_ids(socket.assigns.mode)

    Enum.each(visible_list_ids, fn list_id ->
      send_update(WortwildnisWeb.TermLive.IndexRefactor.List,
        [{:id, list_id}, {action, term}]
      )
    end)
  end
end
