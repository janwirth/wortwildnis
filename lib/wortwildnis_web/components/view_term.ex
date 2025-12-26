defmodule WortwildnisWeb.ViewTerm do
  use WortwildnisWeb, :live_component

  alias WortwildnisWeb.DateFormatter
  alias WortwildnisWeb.ContentFilter
  alias WortwildnisWeb.DescriptionSegmenter

  attr :term, Wortwildnis.Dictionary.Term, required: true
  attr :return_to, :string, default: nil
  attr :current_user, :any, default: nil
  attr :flash, :map, required: true

  def render(assigns) do
    # Load contained_terms lazily if not already loaded
    term =
      case assigns.term.contained_terms do
        %Ash.NotLoaded{} ->
          # Load contained_terms on-demand for this single term
          Ash.load!(assigns.term, [:contained_terms], actor: assigns.current_user)

        _ ->
          assigns.term
      end

    contained_terms =
      case term.contained_terms do
        %Ash.NotLoaded{} -> []
        terms when is_list(terms) -> terms
        _ -> []
      end

    description_segments =
      DescriptionSegmenter.build_description_segments(
        term.description,
        contained_terms
      )

    # Reset translating state if both translations are now available
    translating =
      if term.translation_en && term.translation_es,
        do: false,
        else: assigns[:translating] || false

    assigns =
      assigns
      |> assign(:term, term)
      |> assign(:description_segments, description_segments)
      |> assign(:user_clicked_show, assigns[:user_clicked_show] || false)
      |> assign(:is_clean, is_content_clean?(term))
      |> assign(:expanded_translation_en, assigns[:expanded_translation_en] || false)
      |> assign(:expanded_translation_es, assigns[:expanded_translation_es] || false)
      |> assign(:translating, translating)

    assigns = assign(assigns, :should_blur, should_blur_content?(assigns))

    ~H"""
    <div class="relative flex max-w-3xl flex-col gap-1.5">
      <%= if @should_blur do %>
        <button
          type="button"
          phx-click="toggle_blur"
          phx-target={@myself}
          class="z-10 absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-red-600 text-white border-none rounded-full px-4 py-2 cursor-pointer font-bold hover:bg-red-700 transition-opacity"
        >
          Zu wild? Zeig's mir!
        </button>
      <% end %>

      <div
        class="flex flex-col gap-1.5"
        style={
          if @should_blur,
            do: "filter: blur(5px); transition: filter 0.3s ease; pointer-events: none;",
            else: "transition: filter 1s ease; pointer-events: auto;"
        }
      >
        <!-- 1. headline -->
        <.link
          navigate={~p"/definition/#{@term.name}"}
          rel={if !has_reactions?(@term) && (length(@term.reactions) < 5) , do: "nofollow", else: nil}
        >
          <h2 class="mb-1 text-2xl font-bold text-blue-700 hover:underline">{@term.name}</h2>
        </.link>

    <!-- 3. description / translation -->
        <p
          class="text-base"
          phx-hook=".EnqueueFindContainedTermsForAll"
          id={"description-#{@term.id}"}
          data-term-id={@term.id}
          data-component-id={@myself}
        >
          <%= render_segments(@description_segments) %>
        </p>
        <!-- Colocated hook, on-demand loading of contained terms -->
        <%= if length(@term.contained_terms) == 0 do %>
          <script :type={Phoenix.LiveView.ColocatedHook} name=".EnqueueFindContainedTermsForAll">
            export default {
              mounted() {
                console.log("EnqueueFindContainedTermsForAll mounted")
                const componentId = this.el.dataset.componentId
                this.pushEventTo(componentId, "enqueue_find_contained_terms", { id: this.el.dataset.termId })
              }
            }
          </script>
        <% end %>
        <!--

          <button type="button" phx-click="enqueue_find_contained_terms" phx-target={@myself} class="underline hover:opacity-75 transition-opacity ml-1 italic cursor-pointer">Find contained terms</button>
          -->

        {render_translation(assigns, :en, "🇬🇧", "Translate it!", "Translating.", "Less", "Read more")}
        {render_translation(assigns, :es, "🇪🇸", "Tradúcelo", "Traduciendo.", "Menos", "Ver más")}
        <%= if @term.example do %>
          <p class="text-base mt-2">
            <span class="opacity-70">Beispiel:</span>
            {@term.example}
          </p>
        <% end %>

    <!-- 2. actions and 4. time ago -->
        <div class="flex flex-row flex-wrap gap-2 items-center text-sm opacity-70">
          <%= if @term.scraped_from_mundmische do %>
            <span>mundmische</span>
          <% else %>
            <%= if @term.owner do %>
              <span>
                <%= if @term.is_owner && @current_user do %>
                  Du, {DateFormatter.format_relative_time(@term.created_at)}
                <% else %>
                  {@term.owner.username} {DateFormatter.format_relative_time(@term.created_at)}
                <% end %>
              </span>
            <% end %>
          <% end %>
          <%= if @term.is_owner do %>
            <.link
              class="underline hover:opacity-75 transition-opacity"
              navigate={edit_path(@term, @return_to)}
            >
              Bearbeiten
            </.link>
            <.link
              class="underline hover:opacity-75 transition-opacity"
              phx-click={JS.push("delete", value: %{id: @term.id}) |> hide("##{@term.id}")}
              data-confirm="Are you sure?"
            >
              Löschen
            </.link>
          <% end %>
        </div>

    <!-- 5. reactions -->
        <div class="flex flex-row flex-wrap gap-2 items-center">
          <%= for reaction_type <- [:up, :down, :laugh, :sad, :angry, :surprised, :confused, :thinking] do %>
            <% reactions_of_type =
              Enum.filter(@term.reactions || [], &(&1.reaction_type == reaction_type))

            count = length(reactions_of_type)

            user_reacted =
              if @current_user,
                do: Enum.any?(reactions_of_type, &(&1.user_id == @current_user.id)),
                else: false

            emoji = reaction_emoji(reaction_type) %>
            <div class="flex items-center gap-1">
              <button
                type="button"
                class={[
                  "rounded-full",
                  "w-8",
                  "h-8",
                  "flex",
                  "items-center",
                  "justify-center",
                  "cursor-pointer",
                  if(user_reacted, do: "bg-black text-white dark:bg-white dark:text-black", else: "")
                ]}
                phx-click={if(@current_user, do: "react", else: "redirect_to_login")}
                phx-value-reaction_type={if(@current_user, do: reaction_type, else: nil)}
                phx-target={@myself}
              >
                <span>{emoji}</span>
              </button>
              <%= if count > 0 do %>
                <span class="text-sm">{count}</span>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_translation(
         assigns,
         lang,
         flag,
         translate_text,
         translating_text,
         collapse_text,
         expand_text
       ) do
    lang_str = Atom.to_string(lang)
    translation = Map.get(assigns.term, String.to_atom("translation_#{lang_str}"))
    expanded = Map.get(assigns, String.to_atom("expanded_translation_#{lang_str}"))
    translating = assigns.translating

    assigns =
      assigns
      |> assign(:lang_str, lang_str)
      |> assign(:translation, translation)
      |> assign(:expanded, expanded)
      |> assign(:translating, translating)
      |> assign(:flag, flag)
      |> assign(:translate_text, translate_text)
      |> assign(:translating_text, translating_text)
      |> assign(:collapse_text, collapse_text)
      |> assign(:expand_text, expand_text)

    ~H"""
    <%= if @translation do %>
      <%= if should_truncate?(@translation) do %>
        <p class="text-base text-stone-500 dark:text-stone-300">
          {@flag} {if @expanded, do: @translation, else: truncate_text(@translation)}
          <button
            type="button"
            phx-click="toggle_translation"
            phx-value-lang={@lang_str}
            phx-target={@myself}
            class="underline hover:opacity-75 transition-opacity ml-1 italic cursor-pointer"
          >
            {if @expanded, do: @collapse_text, else: @expand_text}
          </button>
        </p>
      <% else %>
        <p class="text-base text-stone-500 dark:text-stone-300">{@flag} {@translation}</p>
      <% end %>
    <% else %>
      <%= if @translating do %>
        <p class="skeleton skeleton-text text-base">
          {@flag} {@translating_text}
        </p>
      <% else %>
        <p class="text-base text-stone-500 dark:text-stone-300">
          {@flag}
          <button
            type="button"
            phx-click="translate"
            phx-value-id={@term.id}
            phx-value-lang={@lang_str}
            phx-target={@myself}
            class="underline hover:opacity-75 transition-opacity ml-1 italic cursor-pointer"
          >
            {@translate_text}
          </button>
        </p>
      <% end %>
    <% end %>
    """
  end

  defp render_segments(segments) do
    iodata =
      Enum.map(segments, fn
        {:text, text} ->
          # html_escape returns {:safe, iodata}, extract the iodata
          {:safe, escaped} = Phoenix.HTML.html_escape(text)
          escaped

        {:link, slug, text} ->
          # Escape both slug and text, extract iodata from safe tuples
          {:safe, escaped_slug} = Phoenix.HTML.html_escape(slug)
          {:safe, escaped_text} = Phoenix.HTML.html_escape(text)

          [
            ~s(<a href="/definition/),
            escaped_slug,
            ~s(" class="underline opacity-80 hover:opacity-100 transition-opacity">),
            escaped_text,
            ~s(</a>)
          ]
      end)

    {:safe, iodata}
  end

  defp edit_path(term, nil), do: ~p"/terms/#{term}/edit"
  defp edit_path(term, return_to), do: ~p"/terms/#{term}/edit?return_to=#{return_to}"

  defp reaction_emoji(:up), do: "👍"
  defp reaction_emoji(:down), do: "👎"
  defp reaction_emoji(:laugh), do: "😂"
  defp reaction_emoji(:sad), do: "😢"
  defp reaction_emoji(:angry), do: "😠"
  defp reaction_emoji(:surprised), do: "😲"
  defp reaction_emoji(:confused), do: "😕"
  defp reaction_emoji(:thinking), do: "🤔"

  defp is_content_clean?(term) do
    content = "#{term.name} #{term.description || ""}"
    ContentFilter.clean?(content)
  end

  defp should_blur_content?(assigns) do
    !assigns.is_clean && !assigns.user_clicked_show
  end

  defp should_truncate?(text) when is_binary(text) do
    # Only truncate if text is longer than 140 chars AND we can truncate at least 60 chars
    # This means the original text must be at least 200 chars
    String.length(text) >= 200
  end

  defp should_truncate?(_), do: false

  defp truncate_text(text) when is_binary(text) do
    # Truncate to 140 characters, trying to break at word boundaries
    if String.length(text) <= 140 do
      text
    else
      truncated = String.slice(text, 0, 140)
      # Try to find the last space before 140 to avoid cutting words
      case find_last_space(truncated) do
        nil ->
          # No space found, just truncate at 140
          "#{truncated}…"

        last_space ->
          # Truncate at the last space (ensures we have at least 60 chars since should_truncate? already checked)
          "#{String.slice(text, 0, last_space)}…"
      end
    end
  end

  defp truncate_text(_), do: ""

  defp find_last_space(text) do
    # Search backwards from position 140 (or end of string) to find the last space
    find_last_space(text, String.length(text) - 1)
  end

  defp find_last_space(_text, -1), do: nil

  defp find_last_space(text, pos) do
    case String.at(text, pos) do
      " " -> pos
      _ -> find_last_space(text, pos - 1)
    end
  end

  defp has_reactions?(term) do
    case term.reactions do
      %Ash.NotLoaded{} -> false
      reactions when is_list(reactions) -> length(reactions) > 0
      _ -> false
    end
  end

  # def handle_event("enqueue_find_contained_terms", %{"id" => id}, socket) do
  #   term = Ash.get!(Wortwildnis.Dictionary.Term, id, actor: socket.assigns.current_user)
  #   term
  #   |> Ash.Changeset.for_update(:enqueue_find_contained_terms)
  #   |> Ash.update!(actor: socket.assigns.current_user)
  #   {:noreply, socket}
  # end
  def handle_event("enqueue_find_contained_terms", _args, socket) do
    term =
      Ash.get!(Wortwildnis.Dictionary.Term, socket.assigns.term.id,
        actor: socket.assigns.current_user
      )

    term
    |> Ash.Changeset.for_update(:enqueue_find_contained_terms)
    |> Ash.update!(actor: socket.assigns.current_user)

    {:noreply, socket}
  end

  @impl true
  def handle_event("translate", %{"id" => id, "lang" => _lang}, socket) do
    term = Ash.get!(Wortwildnis.Dictionary.Term, id, actor: socket.assigns.current_user)

    # Set translating state (both languages are translated at the same time)
    socket = assign(socket, :translating, true)

    _result =
      term
      |> Ash.Changeset.for_update(:queue_translate)
      |> Ash.update!(actor: socket.assigns.current_user)

    {:noreply, socket}
  end

  def handle_event("toggle_blur", _params, socket) do
    {:noreply, assign(socket, :user_clicked_show, true)}
  end

  def handle_event("toggle_translation", %{"lang" => lang}, socket) do
    case lang do
      "en" ->
        current_value = socket.assigns[:expanded_translation_en] || false
        {:noreply, assign(socket, :expanded_translation_en, !current_value)}

      "es" ->
        current_value = socket.assigns[:expanded_translation_es] || false
        {:noreply, assign(socket, :expanded_translation_es, !current_value)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("redirect_to_login", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/sign-in")}
  end

  def handle_event("react", %{"reaction_type" => reaction_type_str}, socket) do
    unless socket.assigns.current_user do
      send(self(), {:put_flash, :error, "You must be logged in to react"})
      {:noreply, socket}
    else
      reaction_type = String.to_existing_atom(reaction_type_str)

      # Check if user already has this reaction
      existing_reaction =
        (socket.assigns.term.reactions || [])
        |> Enum.find(fn r ->
          r.reaction_type == reaction_type && r.user_id == socket.assigns.current_user.id
        end)

      if existing_reaction do
        # Remove reaction
        result = Ash.destroy(existing_reaction, actor: socket.assigns.current_user)

        case result do
          {:ok, _} ->
            # PubSub will handle the refresh
            {:noreply, socket}

          :ok ->
            # PubSub will handle the refresh
            {:noreply, socket}

          {:error, _error} ->
            send(self(), {:put_flash, :error, "Failed to remove reaction"})
            {:noreply, socket}
        end
      else
        # Add reaction
        case Ash.create(
               Wortwildnis.Social.Reaction,
               %{reaction_type: reaction_type, term_id: socket.assigns.term.id},
               action: :react,
               actor: socket.assigns.current_user
             ) do
          {:ok, _reaction} ->
            # PubSub will handle the refresh
            {:noreply, socket}

          {:error, %Ash.Error.Forbidden{}} ->
            send(self(), {:put_flash, :error, "You don't have permission to react"})
            {:noreply, socket}

          {:error, _error} ->
            send(self(), {:put_flash, :error, "Failed to create reaction"})
            {:noreply, socket}
        end
      end
    end
  end
end
