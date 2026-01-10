defmodule WortwildnisWeb.TermLive.IndexRefactor.List do
  use WortwildnisWeb, :live_component

  alias WortwildnisWeb.LiveView.TermHelpers

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class={"flex flex-col gap-6 #{if assigns[:mode] == :term_of_the_day and length(@terms) == 0, do: "hidden"}"}
    >
      <%= if assigns[:mode] == :term_of_the_day and length(@terms) > 0  do %>
        <h2 class="text-xl opacity-70 font-bold">Begriff des Tages</h2>
      <% end %>
      <div :for={term <- @terms} id={"#{@id}-term-#{term.id}-wrapper"}>
        <.live_component
          id={"#{@id}-term-#{term.id}"}
          current_user={@current_user}
          module={WortwildnisWeb.ViewTerm}
          term={term}
        />
      </div>
      <%= if assigns[:mode] == :search and length(@terms) == 0  do %>
        <h2>Keine Ergebnisse</h2>
      <% end %>
      <%= if assigns[:mode] == :user_reacted_terms and length(@terms) == 0  do %>
        <h2>Nix da.</h2>
      <% end %>
      <%= if assigns[:mode] == :user_submitted_terms and length(@terms) == 0  do %>
        <h2>Nix da.</h2>
      <% end %>
      <%= if assigns[:mode] == :term_of_the_day and length(@terms) > 0  do %>
        <div class="h-12"></div>
      <% end %>
      <div class="flex items-center justify-center pt-4 gap-2">
        <%= if assigns[:total_count] && length(@terms) < assigns[:total_count] do %>
          <button
            phx-click="load_more"
            phx-target={@myself}
            class="px-4 py-2 hover:opacity-75 transition-opacity bg-blue-600 text-white rounded-full cursor-pointer font-bold"
          >
            Mehr laden
          </button>
        <% end %>
        <button
          phx-click="random_term"
          class="border border-black dark:border-white rounded-full px-4 py-2 cursor-pointer font-bold hover:opacity-75 transition-opacity box-border"
        >
          Zufälliger Begriff
        </button>
      </div>
    </div>
    """
  end

  defp default_assigns(socket, %{id: id, current_user: current_user, mode: mode} = params) do
    page = Map.get(params, :page, 1)

    socket
    |> assign(:id, id)
    |> assign(:current_user, current_user)
    |> assign(:mode, mode)
    |> assign(:page, page)
    |> assign(:letter, Map.get(params, :letter))
    |> assign(:query, Map.get(params, :query))
  end

  # GETTIN DATA FOR MODES
  @impl true
  def update(%{mode: :recent} = params, socket) do
    page = Map.get(params, :page, 1)

    {new_terms, total_count} =
      Wortwildnis.Dictionary.Term
      |> Ash.Query.for_read(:read)
      |> Ash.Query.sort(created_at: :desc)
      |> TermHelpers.read_terms_with_count_and_enqueue_find_contained_terms_if_needed(
        params.current_user,
        page
      )

    socket =
      socket
      |> default_assigns(params)
      |> assign(:total_count, total_count)
      |> assign_stream_append(params.mode, new_terms)

    {:ok, socket}
  end

  # GETTIN DATA FOR MODES
  @impl true
  def update(%{mode: :hot} = params, socket) do
    page = Map.get(params, :page, 1)

    {new_terms, total_count} =
      Wortwildnis.Dictionary.Term
      |> Ash.Query.for_read(:recently_reacted)
      |> Ash.Query.sort(created_at: :desc)
      |> TermHelpers.read_terms_with_count_and_enqueue_find_contained_terms_if_needed(
        params.current_user,
        page
      )

    socket =
      socket
      |> default_assigns(params)
      |> assign(:total_count, total_count)
      |> assign_stream_append(params.mode, new_terms)

    {:ok, socket}
  end

  @impl true
  def update(%{mode: :letter, letter: letter} = params, socket) do
    page = Map.get(params, :page, 1)

    {new_terms, total_count} =
      Wortwildnis.Dictionary.Term
      |> Ash.Query.for_read(:by_letter, letter: letter)
      |> TermHelpers.read_terms_with_count_and_enqueue_find_contained_terms_if_needed(
        params.current_user,
        page
      )

    socket =
      socket
      |> default_assigns(params)
      |> assign(:total_count, total_count)
      |> assign_stream_append(params.mode, new_terms)

    {:ok, socket}
  end

  def update(%{mode: :search, query: query} = params, socket) do
    IO.puts("Updating search: #{query}")
    page = Map.get(params, :page, 1)

    {new_terms, total_count} =
      Wortwildnis.Dictionary.Term
      |> Ash.Query.for_read(:search, q: query)
      |> TermHelpers.read_terms_with_count_and_enqueue_find_contained_terms_if_needed(
        params.current_user,
        page
      )

    socket =
      socket
      |> default_assigns(params)
      |> assign(:total_count, total_count)
      |> assign_stream_append(params.mode, new_terms)

    {:ok, socket}
  end

  def update(%{mode: :user_submitted_terms, user_id: _user_id} = params, socket) do
    page = Map.get(params, :page, 1)

    {new_terms, total_count} =
      Wortwildnis.Dictionary.Term
      |> Ash.Query.for_read(:user_submitted_terms, user_id: params.current_user.id)
      |> TermHelpers.read_terms_with_count_and_enqueue_find_contained_terms_if_needed(
        params.current_user,
        page
      )

    socket =
      socket
      |> default_assigns(params)
      |> assign(:total_count, total_count)
      |> assign_stream_append(params.mode, new_terms)

    {:ok, socket}
  end

  def update(%{mode: :user_reacted_terms, user_id: _user_id} = params, socket) do
    page = Map.get(params, :page, 1)

    {new_terms, total_count} =
      Wortwildnis.Dictionary.Term
      |> Ash.Query.for_read(:user_reacted_terms, user_id: params.current_user.id)
      |> TermHelpers.read_terms_with_count_and_enqueue_find_contained_terms_if_needed(
        params.current_user,
        page
      )

    socket =
      socket
      |> default_assigns(params)
      |> assign(:total_count, total_count)
      |> assign_stream_append(params.mode, new_terms)

    {:ok, socket}
  end

  def update(%{mode: :term_of_the_day} = params, socket) do
    {:ok, today} = Date.from_erl(:calendar.local_time() |> elem(0))
    page = Map.get(params, :page, 1)

    {new_terms, total_count} =
      Wortwildnis.Dictionary.Term
      |> Ash.Query.for_read(:term_of_the_day, date: today)
      |> TermHelpers.read_terms_with_count_and_enqueue_find_contained_terms_if_needed(
        params.current_user,
        page
      )

    socket =
      socket
      |> default_assigns(params)
      |> assign(:total_count, total_count)
      |> assign_stream_append(params.mode, new_terms)

    {:ok, socket}
  end

  # HANDLING UPDATES
  @impl true
  def update(%{update_term: term} = _params, socket) do
    # term = WortwildnisWeb.LiveView.TermHelpers.get_term_with_loads(term.id, socket.assigns.current_user)
    IO.puts("UPDATING #{socket.assigns.id}-term-#{term.id}")

    # Update the first occurrence of the term and remove any duplicates
    {updated_terms, _found} =
      Enum.reduce(socket.assigns.terms, {[], false}, fn t, {acc, found} ->
        cond do
          t.id == term.id && !found -> {acc ++ [term], true}
          # Skip duplicates
          t.id == term.id && found -> {acc, true}
          true -> {acc ++ [t], found}
        end
      end)

    socket = assign(socket, :terms, updated_terms)
    {:ok, socket}
  end

  def update(%{delete_term_id: term_id} = _params, socket) do
    terms =
      socket.assigns.terms
      |> Enum.filter(fn t -> t.id != term_id end)

    socket = assign(socket, :terms, terms)
    {:ok, socket}
  end

  defp assign_stream_append(socket, _mode, new_terms) do
    existing_terms = Map.get(socket.assigns, :terms, [])

    # If this is the first page (page 1), replace the list
    # Otherwise, append to existing terms
    terms =
      if socket.assigns.page == 1 do
        new_terms
      else
        # Filter out any terms that already exist in the list to avoid duplicates
        existing_ids = MapSet.new(existing_terms, & &1.id)

        new_unique_terms =
          Enum.reject(new_terms, fn term -> MapSet.member?(existing_ids, term.id) end)

        existing_terms ++ new_unique_terms
      end

    assign(socket, :terms, terms)
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    if length(socket.assigns.terms) < socket.assigns.total_count do
      new_page = socket.assigns.page + 1
      params = build_update_params(socket, new_page)
      send_update(__MODULE__, params)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp build_update_params(socket, new_page) do
    base_params = %{
      id: socket.assigns.id,
      current_user: socket.assigns.current_user,
      mode: socket.assigns.mode,
      page: new_page
    }

    case socket.assigns.mode do
      :letter ->
        Map.put(base_params, :letter, socket.assigns[:letter])

      :search ->
        Map.put(base_params, :query, socket.assigns[:query])

      :user_submitted_terms ->
        Map.put(base_params, :user_id, socket.assigns.current_user.id)

      :user_reacted_terms ->
        Map.put(base_params, :user_id, socket.assigns.current_user.id)

      _ ->
        base_params
    end
  end
end
