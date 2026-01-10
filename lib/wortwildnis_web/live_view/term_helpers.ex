defmodule WortwildnisWeb.LiveView.TermHelpers do
  @moduledoc """
  Shared helper functions for fetching and loading terms in LiveViews.
  """

  use Phoenix.LiveView

  alias SEO

  @terms_per_page 50

  @doc """
  Loads terms filtered by letter with pagination.
  """
  def load_terms_by_letter(socket, letter, page) do
    terms = Wortwildnis.Dictionary.Term

    # First, get total count
    total_count =
      terms
      |> Ash.Query.for_read(:by_letter, letter: letter)
      |> Ash.read!(actor: socket.assigns[:current_user])
      |> length()

    # Then get paginated results - don't load contained_terms here
    offset = (page - 1) * @terms_per_page

    term_list =
      terms
      |> Ash.Query.for_read(:by_letter, letter: letter)
      |> Ash.Query.limit(@terms_per_page)
      |> Ash.Query.offset(offset)
      |> Ash.read!(
        actor: socket.assigns[:current_user],
        load: [:is_owner, :reactions, :owner]
      )

    total_pages = ceil(total_count / @terms_per_page)

    seo_item = %{
      title: "Begriffe mit #{String.upcase(letter)}",
      description: "Alphabetische Liste aller Begriffe, die mit #{String.upcase(letter)} beginnen"
    }

    socket
    |> assign(:letter, letter)
    |> assign(:page, page)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
    |> assign(:terms_per_page, @terms_per_page)
    |> assign(:page_title, "Begriffe mit #{String.upcase(letter)}")
    |> assign_new(:current_user, fn -> nil end)
    |> SEO.assign(seo_item)
    |> assign(:seo_temporary, true)
    |> stream(:terms, term_list, reset: true)
  end

  defp local_today do
    {:ok, date} = Date.from_erl(:calendar.local_time() |> elem(0))
    date
  end

  @doc """
  Loads all terms, excluding the term of the day if it exists.
  """
  def load_all_terms(socket) do
    terms = Wortwildnis.Dictionary.Term

    # Get term of the day for today - don't load contained_terms
    term_of_the_day =
      case Ash.read_one(
             terms
             |> Ash.Query.for_read(:term_of_the_day, date: local_today()),
             actor: socket.assigns[:current_user],
             load: [:is_owner, :reactions, :owner]
           ) do
        {:ok, term} -> term
        {:error, _} -> nil
      end

    # Get all terms, excluding the term of the day if it exists
    # Don't load contained_terms - it will be loaded lazily
    term_stream =
      terms
      |> Ash.Query.sort(created_at: :desc)
      |> Ash.read!(
        actor: socket.assigns[:current_user],
        load: [:is_owner, :reactions, :owner]
      )
      |> Enum.reject(fn term ->
        term_of_the_day && term.id == term_of_the_day.id
      end)

    # Homepage - stable SEO per INDEXING_RULES.md
    seo_item = %{
      title: "Das Deutsche Urban Dictionary",
      description: "Wortwildnis - Ein Wörterbuch für deutsche Begriffe und Slang"
    }

    socket
    |> assign(:page_title, "Startseite")
    |> assign(:term_of_the_day, term_of_the_day)
    |> assign_new(:current_user, fn -> nil end)
    |> SEO.assign(seo_item)
    |> assign(:seo_temporary, true)
    |> stream(:terms, term_stream, reset: true)
  end

  @doc """
  Parses page parameter from query string.
  """
  def parse_page(nil), do: 1

  def parse_page(page_string) when is_binary(page_string) do
    case Integer.parse(page_string) do
      {page, _} when page > 0 -> page
      _ -> 1
    end
  end

  def parse_page(_), do: 1

  @doc """
  Gets the standard term loads for LiveViews.
  Don't load contained_terms here - it's expensive and causes massive LATERAL joins.
  Load it lazily in the component when needed.
  """
  def standard_term_loads do
    [:is_owner, :reactions, :owner, :contained_terms_cache]
  end

  @doc """
  Gets a term with standard loads.
  """
  def get_term_with_loads(id, actor) do
    Ash.get!(Wortwildnis.Dictionary.Term, id,
      actor: actor,
      load: standard_term_loads()
    )
  end

  @doc """
  Reads terms with standard loads and a limit of 10.
  """
  @spec read_terms(atom() | Ash.Query.t(), any()) ::
          [struct()]
          | %{
              :__struct__ => Ash.Page.Keyset | Ash.Page.Offset,
              :count => integer(),
              :limit => integer(),
              :more? => boolean(),
              :rerun => {Ash.Query.t(), [{any(), any()}]},
              :results => [struct()],
              optional(:after) => nil | binary(),
              optional(:before) => nil | binary(),
              optional(:offset) => integer()
            }
  def read_terms(query, current_user) do
    query
    |> Ash.Query.limit(10)
    |> Ash.Query.load(standard_term_loads())
    |> Ash.read!(actor: current_user)
  end

  @doc """
  Reads terms with pagination and returns the total count.
  Uses efficient COUNT(*) query for counting.
  """
  def read_terms_with_count_and_enqueue_find_contained_terms_if_needed(query, current_user, page \\ 1) do
    offset = (page - 1) * 10

    terms =
      query
      |> Ash.Query.limit(10)
      |> Ash.Query.offset(offset)
      |> Ash.Query.load(standard_term_loads())
      |> Ash.read!(actor: current_user)

    # Get total count efficiently - just count, don't load
    total_count =
      query
      |> Ash.count!(actor: current_user)

    # enqueue find contained terms for all terms if cache empty
    Enum.each(terms, fn term ->
      if is_nil(term.contained_terms_cache) do
        IO.puts("Enqueueing find contained terms for term #{term.id}")
        Ash.update!(term, action: :enqueue_find_contained_terms)
      end
    end)


    {terms, total_count}
  end
end
