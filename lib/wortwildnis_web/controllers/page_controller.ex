defmodule WortwildnisWeb.PageController do
  use WortwildnisWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
