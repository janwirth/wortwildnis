defmodule Wortwildnis.Dictionary.Term.SEO do
  @moduledoc """
  SEO protocol implementations for Term struct.
  """

  defimpl SEO.Site.Build, for: Wortwildnis.Dictionary.Term do
    def build(term, _conn) do
      slug = Slug.slugify(term.name)
      description = String.slice(term.description || "", 0..159)
      url = WortwildnisWeb.Endpoint.url() <> "/definition/#{slug}"

      SEO.Site.build(
        url: url,
        title: "#{term.name}",
        description: description
      )
    end
  end

  defimpl SEO.OpenGraph.Build, for: Wortwildnis.Dictionary.Term do
    def build(term, _conn) do
      slug = Slug.slugify(term.name)
      description = String.slice(term.description || "", 0..159)
      url = WortwildnisWeb.Endpoint.url() <> "/definition/#{slug}"

      SEO.OpenGraph.build(
        title: term.name,
        description: description,
        url: url,
        locale: "de_DE"
      )
    end
  end

  defimpl SEO.Twitter.Build, for: Wortwildnis.Dictionary.Term do
    def build(term, _conn) do
      description = String.slice(term.description || "", 0..159)

      SEO.Twitter.build(
        title: term.name,
        description: description
      )
    end
  end

  defimpl SEO.Breadcrumb.Build, for: Wortwildnis.Dictionary.Term do
    def build(term, _conn) do
      slug = Slug.slugify(term.name)
      base_url = WortwildnisWeb.Endpoint.url()

      SEO.Breadcrumb.List.build([
        %{name: "Startseite", item: base_url <> "/"},
        %{name: term.name, item: base_url <> "/definition/#{slug}"}
      ])
    end
  end
end
