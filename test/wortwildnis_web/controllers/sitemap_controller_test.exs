defmodule WortwildnisWeb.SitemapControllerTest do
  use WortwildnisWeb.ConnCase, async: false

  describe "GET /sitemap.xml" do
    test "returns valid XML sitemap", %{conn: conn} do
      conn = get(conn, ~p"/sitemap.xml")

      assert response_content_type(conn, :xml) == "text/xml; charset=utf-8"
      assert conn.status == 200

      body = response(conn, 200)

      # Should contain XML declaration
      assert body =~ ~r/<?xml version="1.0" encoding="UTF-8"?>/

      # Should contain urlset namespace
      assert body =~ ~r/<urlset xmlns="http:\/\/www.sitemaps.org\/schemas\/sitemap\/0.9">/

      # Should contain homepage
      assert body =~ ~r/<loc>.*\/<\/loc>/

      # Should contain changefreq
      assert body =~ ~r/<changefreq>weekly<\/changefreq>/
    end

    test "includes only homepage and curated terms", %{conn: conn} do
      conn = get(conn, ~p"/sitemap.xml")
      body = response(conn, 200)

      # Count URL entries (should be homepage + max 20 terms)
      url_count = Regex.scan(~r/<url>/, body) |> length()

      # Should have between 1 (homepage only) and 21 (homepage + 20 terms)
      assert url_count >= 1 and url_count <= 21

      # Should NOT contain excluded paths
      refute body =~ ~r/\/neu/
      refute body =~ ~r/\/alphabetisch/
      refute body =~ ~r/\/terms\/new/
    end

    test "only includes terms with slugified URLs and 5+ character names", %{conn: conn} do
      conn = get(conn, ~p"/sitemap.xml")
      body = response(conn, 200)

      # All definition URLs should be slugified (no spaces)
      definition_urls = Regex.scan(~r/<loc>.*\/definition\/([^<]+)<\/loc>/, body)

      Enum.each(definition_urls, fn [_, slug] ->
        # Slugs should not contain spaces or special characters that need encoding
        refute slug =~ " "
        # Decoded slug should be at least 5 characters (quality filter)
        decoded_slug = URI.decode(slug)
        assert String.length(decoded_slug) >= 5,
               "Term slug '#{decoded_slug}' is less than 5 characters"
      end)
    end
  end
end
