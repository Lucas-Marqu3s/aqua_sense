defmodule AquaSenseWeb.PageController do
  use AquaSenseWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
