defmodule WortwildnisWeb.TermLive.Form do
  use WortwildnisWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        {@page_title}
        <:subtitle>
          Verwenden Sie dieses Formular, um Begriffseinträge in Ihrer Datenbank zu verwalten.
        </:subtitle>
      </.header>

      <.form
        for={@form}
        id="term-form"
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:description]} type="textarea" label="Beschreibung" />
        <.input field={@form[:example]} type="textarea" label="Beispiel" />
        <div class="flex flex-row gap-2 justify-between">
          <.link
            navigate={return_path(@return_to, @term)}
            class="underline hover:opacity-75 transition-opacity cursor-pointer text-red-800 dark:text-red-400"
          >
            Abbrechen
          </.link>
          <button
            phx-disable-with="Speichern..."
            class="-mx-2 px-2 font-bold text-underlined hover:bg-black hover:text-white dark:hover:bg-white dark:hover:text-black cursor-pointer"
          >
            Speichern
          </button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    term =
      case params["id"] do
        nil -> nil
        id -> Ash.get!(Wortwildnis.Dictionary.Term, id, actor: socket.assigns.current_user)
      end

    action = if is_nil(term), do: "Neuer", else: "Bearbeiten"
    page_title = action <> " " <> "Begriff"

    socket =
      socket
      |> assign(:return_to, return_to(params["return_to"]))
      |> assign(term: term)
      |> assign(:page_title, page_title)
      |> assign_form()

    # Restore draft from user profile if it's a new term and user is logged in
    socket =
      if is_nil(term) && socket.assigns.current_user do
        restore_draft(socket)
      else
        socket
      end

    {:ok, socket}
  end

  defp return_to("show"), do: "show"
  defp return_to("define"), do: "define"
  defp return_to(_), do: "index"

  @impl true
  def handle_event("validate", %{"term" => term_params}, socket) do
    # Save draft to user profile on validation (only for new terms and logged in users)
    socket =
      if is_nil(socket.assigns.term) && socket.assigns.current_user do
        save_draft(socket, term_params)
      else
        socket
      end

    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, term_params))}
  end

  def handle_event("save", %{"term" => term_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form,
           params: term_params,
           actor: socket.assigns.current_user
         ) do
      {:ok, term} ->
        notify_parent({:saved, term})

        # Clear draft from user profile after successful save
        socket =
          if socket.assigns.current_user do
            clear_draft(socket)
          else
            socket
          end

        success_message =
          case socket.assigns.form.source.type do
            :create -> "Begriff erfolgreich erstellt"
            :update -> "Begriff erfolgreich aktualisiert"
            _ -> "Begriff erfolgreich gespeichert"
          end

        socket =
          socket
          |> put_flash(:info, success_message)
          |> push_navigate(to: return_path(socket.assigns.return_to, term))

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
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

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{term: term}} = socket) do
    form =
      if term do
        AshPhoenix.Form.for_update(term, :update_owned_term,
          as: "term",
          actor: socket.assigns.current_user
        )
      else
        AshPhoenix.Form.for_create(Wortwildnis.Dictionary.Term, :create_term_with_owner,
          as: "term",
          actor: socket.assigns.current_user
        )
      end

    assign(socket, form: to_form(form))
  end

  defp return_path("index", _term), do: ~p"/"
  defp return_path("alphabet", _term), do: ~p"/alphabetisch"

  defp return_path("define", term) do
    slug = Slug.slugify(term.name)
    ~p"/definition/#{slug}"
  end

  defp restore_draft(socket) do
    user = socket.assigns.current_user

    # Reload user to ensure we have the latest term_draft
    user = Ash.get!(Wortwildnis.Accounts.User, user.id, actor: user)

    socket = assign(socket, :current_user, user)

    case user.term_draft do
      nil ->
        socket

      draft when is_map(draft) ->
        # Restore draft data into the form
        term_params = %{
          "name" => Map.get(draft, "name", "") || "",
          "description" => Map.get(draft, "description", "") || "",
          "example" => Map.get(draft, "example", "") || ""
        }

        # Only restore if there's actual content
        if term_params["name"] != "" || term_params["description"] != "" do
          assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, term_params))
        else
          socket
        end

      _ ->
        socket
    end
  end

  defp save_draft(socket, term_params) do
    user = socket.assigns.current_user

    draft_data = %{
      "name" => Map.get(term_params, "name", "") || "",
      "description" => Map.get(term_params, "description", "") || "",
      "example" => Map.get(term_params, "example", "") || ""
    }

    # Only save if there's actual content
    if draft_data["name"] != "" || draft_data["description"] != "" do
      case Ash.update(user,
             action: :update_term_draft,
             params: %{term_draft: draft_data},
             actor: user
           ) do
        {:ok, updated_user} ->
          assign(socket, :current_user, updated_user)

        {:error, _} ->
          socket
      end
    else
      # Clear draft if form is empty
      clear_draft(socket)
    end
  end

  defp clear_draft(socket) do
    user = socket.assigns.current_user

    case Ash.update(user, action: :update_term_draft, params: %{term_draft: nil}, actor: user) do
      {:ok, updated_user} ->
        assign(socket, :current_user, updated_user)

      {:error, _} ->
        socket
    end
  end
end
