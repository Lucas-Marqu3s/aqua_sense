defmodule AquaSenseWeb.SignInLive do
  use AquaSenseWeb, :live_view

  alias AquaSenseWeb.Components.TextField
  alias AquaSenseWeb.Components.Button, as: MishkaButton

  on_mount {AquaSenseWeb.LiveUserAuth, :live_no_user}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, error: nil, loading: false)}
  end

  def handle_event("sign_in", %{"email" => email, "password" => password}, socket) do
    socket = assign(socket, loading: true, error: nil)

    case AquaSense.Accounts.User
         |> Ash.Query.for_read(:sign_in_with_password, %{email: email, password: password})
         |> Ash.read_one(domain: AquaSense.Accounts) do
      {:ok, user} when not is_nil(user) ->
        token = user.__metadata__[:token]
        path = "/auth/user/password/sign_in_with_token?#{URI.encode_query(%{token: token, next: "/"})}"
        {:noreply, redirect(socket, to: path)}

      _ ->
        {:noreply, assign(socket, error: "Email ou senha inválidos.", loading: false)}
    end
  end
end
