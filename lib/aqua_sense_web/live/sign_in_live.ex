defmodule AquaSenseWeb.SignInLive do
  use AquaSenseWeb, :live_view

  alias AquaSenseWeb.Components.TextField
  alias AquaSenseWeb.Components.Button, as: MishkaButton

  on_mount {AquaSenseWeb.LiveUserAuth, :live_no_user}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, error: nil)}
  end
end
