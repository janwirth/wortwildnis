defmodule WortwildnisWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use WortwildnisWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_user, :any, required: true, doc: "the current authenticated user"

  attr :socket, :any, default: nil, doc: "the LiveView socket (if available)"

  attr :search_input_value, :string, default: "", doc: "the current search input value"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="px-4 py-4 sm:px-6 lg:px-8">
      <div class="flex-none w-full">
        <div class="flex items-center justify-between gap-4 flex-wrap">
          <ul class="flex flex-row flex-wrap px-1 gap-2 items-center">
            <li>
              <.link navigate={~p"/"} class="hover:opacity-75 transition-opacity">
                <img src={~p"/images/logo_w.webp"} alt="Wortwildnis" class="h-8 w-auto" />
              </.link>
            </li>

            <li>
              <.link
                navigate={~p"/alphabetisch"}
                class="text-sm hover:opacity-75 transition-opacity text-blue-500 hover:text-blue-600"
              >
                Von A bis Z
              </.link>
            </li>
          </ul>
          <div class="flex-1 flex justify-center">
            <.search_form value={@search_input_value} socket={@socket} current_user={@current_user} />
          </div>
          <div class="flex items-center gap-4">
            <.theme_toggle />
            <.user_info current_user={@current_user} socket={@socket} />
            <!-- {Gettext.get_locale(WortwildnisWeb.Gettext)} -->
          </div>
        </div>
      </div>
    </header>

    <main class="px-4 py-8 sm:px-6 lg:px-8 gap-16 flex sm:flex-row flex-col mx-auto max-w-7xl">
      <div class="space-y-4 max-w-2xl flex-1">
        {render_slot(@inner_block)}
      </div>
      <aside class="sm:max-w-[40%] flex flex-col gap-4">
        <div>
          <div class="text-xl opacity-80 font-bold">
            Wortwildnis lebt von Dir.
          </div>
          <.button
            variant="primary"
            class="mt-4 bg-blue-600 text-white border-none rounded-full px-4 py-2 cursor-pointer font-bold hover:bg-blue-700 transition-opacity inline-block"
            navigate={if @current_user, do: ~p"/terms/new", else: ~p"/sign-in"}
          >
            → Begriff definieren
          </.button>
        </div>
        <div class="text-base ">
          <div class="  font-bold mb-2">
            Was ist mit Mundmische passiert?
          </div>
          <p>
            Das haben wir uns auch gefragt.
            <br />Das beste was wir finden konnten, zeigt <a
              target="_blank"
              class="underline cursor-pointer hover:opacity-75 transition-opacity"
              href="https://www.reddit.com/r/German/comments/1ai72yj/what_happened_to_mundmischede/"
            >dieser Reddit post</a>.
          </p>
          <p class="mt-2">
            Die meisten Begriffe sind von mundmische.de übernommen. Wir haben dem Mundmische.de Team geschrieben, und bis heute noch keine Antwort erhalten.
          </p>
          <p class="mt-2">
            Automatische Übersetzung durch DeepL.
          </p>
          <a href={"https://janwirth.notion.site/Wortwildnis-Impressum-Datenschutz-2d75cbd3c0c6806fbdebfca8d7f10894"} target="_blank" class="text-sm underline cursor-pointer hover:opacity-75 transition-opacity mt-4">
          Impressum & Datenschutz
          </a>
        </div>
      </aside>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Renders user info, showing sign in/sign up links when not authenticated,
  or user email and sign out link when authenticated.
  """
  attr :current_user, :any, default: nil
  attr :socket, :any, default: nil

  def user_info(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <%= if @current_user do %>
        <.link navigate={~p"/profile"} class="text-sm hover:opacity-75 transition-opacity">
          <span class="text-sm">{@current_user.username}</span>
        </.link>
        <.link href={~p"/sign-out"} class="text-sm underline">
          Abmelden
        </.link>
      <% else %>
        <.link href={~p"/sign-in"} class="text-sm underline">
          Anmelden
        </.link>
        <.link href={~p"/register"} class="text-sm underline">
          Registrieren
        </.link>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a search form that navigates to search results with real-time search and debouncing.
  """
  attr :socket, :any, default: nil
  attr :value, :string, default: ""
  attr :current_user, :any, default: nil

  def search_form(assigns) do
    total_count =
      Wortwildnis.Dictionary.Term
      |> Ash.read!(actor: assigns.current_user)
      |> length()

    assigns = assign(assigns, :total_count, total_count)

    ~H"""
    <.form
      for={%{}}
      as={:search}
      phx-change="search"
      phx-debounce="300"
      class="flex gap-2 w-full items-center"
    >
      <label class="" for="search-input">Suche:</label>
      <input
        type="text"
        id="search-input"
        name="q"
        phx-debounce="300"
        value={@value}
        placeholder={"#{@total_count} Begriffe"}
        class=""
        autocomplete="off"
      />
    </.form>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center rounded-full">
      <div class="absolute w-1/3 h-full rounded-full bg-black dark:bg-white left-0 [[data-theme=system]_&]:left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3 relative z-10"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon
          name="hero-computer-desktop-micro"
          class={[
            "size-4 opacity-75 hover:opacity-100",
            "text-black dark:text-white",
            "[[data-theme=system]_&]:text-white [[data-theme=system]_&]:dark:text-black"
          ]}
        />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3 relative z-10"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon
          name="hero-sun-micro"
          class={[
            "size-4 opacity-75 hover:opacity-100",
            "text-black dark:text-white",
            "[[data-theme=light]_&]:text-white"
          ]}
        />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3 relative z-10"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon
          name="hero-moon-micro"
          class={[
            "size-4 opacity-75 hover:opacity-100",
            "text-black dark:text-white",
            "[[data-theme=dark]_&]:text-black"
          ]}
        />
      </button>
    </div>
    """
  end
end
