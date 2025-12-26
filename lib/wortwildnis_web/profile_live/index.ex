defmodule WortwildnisWeb.ProfileLive.Index do
  use WortwildnisWeb, :live_component

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_username_form()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="pb-4">
        <h2 class="text-xl opacity-70 font-bold ">Mein Profil</h2>
        <.form
          for={@username_form}
          phx-submit="update_username"
          phx-target={@myself}
          id="username-form"
          class="flex flex-col gap-2"
        >
          <div class="max-w-sm">
            <.input
              field={@username_form[:username]}
              type="text"
              label="Benutzername"
              required
            />
          </div>
          <div>
            <.button
              type="submit"
              class="bg-blue-600 text-white border-none rounded-full px-4 py-2 cursor-pointer font-bold hover:bg-blue-700 transition-opacity inline-block"
            >
              Speichern
            </.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("update_username", %{"username" => username_params}, socket) do
    user = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.username_form,
           params: username_params,
           actor: user
         ) do
      {:ok, updated_user} ->
        # Send message to parent LiveView to update current_user and show flash
        send(self(), {:user_updated, updated_user, "Benutzername wurde aktualisiert"})

        socket =
          socket
          |> assign(:current_user, updated_user)
          |> assign_username_form()

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, username_form: form)}
    end
  end

  defp assign_username_form(socket) do
    user = socket.assigns.current_user
    form = AshPhoenix.Form.for_update(user, :update_username, as: "username", actor: user)
    assign(socket, username_form: to_form(form))
  end
end
