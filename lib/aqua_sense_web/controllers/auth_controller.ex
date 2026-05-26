defmodule AquaSenseWeb.AuthController do
  use AquaSenseWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, {:password, :register}, _user, _token) do
    conn
    |> put_flash(:info, "Conta criada! Aguarde a liberação pelo administrador para acessar.")
    |> redirect(to: ~p"/sign-in")
  end

  def success(conn, _activity, user, _token) do
    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> redirect(to: ~p"/")
  end

  def failure(conn, {:password, :register}, _reason) do
    conn
    |> put_flash(:error, "Erro ao criar conta. Verifique os dados informados.")
    |> redirect(to: ~p"/register")
  end

  def failure(conn, _activity, %AshAuthentication.Errors.AuthenticationFailed{
        caused_by: %AshAuthentication.Errors.UnconfirmedUser{}
      }) do
    conn
    |> put_flash(:error, "Acesso pendente. Aguarde a liberação pelo administrador.")
    |> redirect(to: ~p"/sign-in")
  end

  def failure(conn, _activity, _reason) do
    conn
    |> put_flash(:error, "Email ou senha inválidos.")
    |> redirect(to: ~p"/sign-in")
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session(:aqua_sense)
    |> put_flash(:info, "You are now signed out")
    |> redirect(to: return_to)
  end
end
