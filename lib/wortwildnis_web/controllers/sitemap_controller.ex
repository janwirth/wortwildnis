defmodule WortwildnisWeb.SitemapController do
  use WortwildnisWeb, :controller

  def index(conn, _params) do
    # Get the base URL from the endpoint config
    base_url = WortwildnisWeb.Endpoint.url()

    # ONLY include homepage - changefreq weekly per SEO recovery rules
    static_routes = [
      %{loc: "#{base_url}/", changefreq: "weekly"}
    ]

    # Get top 10-20 curated evergreen terms with most reactions
    # These are the most valuable, stable content for SEO recovery
    curated_terms =
      Wortwildnis.Dictionary.Term
      |> Ash.Query.for_read(:recently_reacted)
      |> Ash.Query.load([:reactions, :updated_at])
      |> Ash.read!(authorize?: false)
      # Filter: only terms with 5+ character names (quality filter)
      |> Enum.filter(fn term -> String.length(term.name) >= 5 end)
      # Sort by reaction count in Elixir after loading
      |> Enum.sort_by(fn term -> -length(term.reactions) end)
      |> Enum.take(20)

    # Create sitemap entries ONLY for curated top terms
    # Use slugified names for clean URLs
    term_routes =
      Enum.map(curated_terms, fn term ->
        # Normalize URL using slugify
        slug = Slug.slugify(term.name)

        %{
          loc: "#{base_url}/definition/#{URI.encode(slug)}",
          lastmod: format_date(term.updated_at),
          changefreq: "weekly"
          # priority: "0.9"
        }
      end)

    # ONLY homepage + curated terms during recovery
    # NO /neu, /alphabetisch, /terms/new, or alphabet letters
    urls = static_routes ++ term_routes

    xml = generate_sitemap_xml(urls)

    conn
    |> put_resp_content_type("text/xml")
    |> send_resp(200, xml)
  end

  defp generate_sitemap_xml(urls) do
    url_entries =
      Enum.map(urls, fn url ->
        """
          <url>
            <loc>#{url.loc}</loc>
        #{if Map.has_key?(url, :lastmod) && url.lastmod, do: "    <lastmod>#{url.lastmod}</lastmod>\n", else: ""}#{if Map.has_key?(url, :changefreq), do: "    <changefreq>#{url.changefreq}</changefreq>\n", else: ""}#{if Map.has_key?(url, :priority), do: "    <priority>#{url.priority}</priority>\n", else: ""}  </url>
        """
      end)
      |> Enum.join("")

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{url_entries}</urlset>
    """
  end

  defp format_date(%DateTime{} = datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end

  defp format_date(%NaiveDateTime{} = naive_datetime) do
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> format_date()
  end

  defp format_date(_), do: nil
end
