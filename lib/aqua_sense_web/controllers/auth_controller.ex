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

  def failure(conn, {:password, :register}, reason) do
    if unconfirmed_user?(reason) do
      conn
      |> put_flash(:info, "Conta criada! Aguarde a liberação pelo administrador para acessar.")
      |> redirect(to: ~p"/sign-in")
    else
      conn
      |> put_flash(:error, "Erro ao criar conta. Verifique os dados informados.")
      |> redirect(to: ~p"/register")
    end
  end

  def failure(conn, _activity, reason) do
    if unconfirmed_user?(reason) do
      conn
      |> put_flash(:error, "Acesso pendente. Aguarde a liberação pelo administrador.")
      |> redirect(to: ~p"/sign-in")
    else
      conn
      |> put_flash(:error, "Email ou senha inválidos.")
      |> redirect(to: ~p"/sign-in")
    end
  end

  # AshAuthentication wraps this error differently depending on the code path
  # (register vs sign-in), so we walk `caused_by`/`errors` instead of matching
  # on a fixed shape.
  defp unconfirmed_user?(%AshAuthentication.Errors.UnconfirmedUser{}), do: true
  defp unconfirmed_user?(%{caused_by: caused_by}), do: unconfirmed_user?(caused_by)
  defp unconfirmed_user?(%{errors: errors}) when is_list(errors), do: Enum.any?(errors, &unconfirmed_user?/1)
  defp unconfirmed_user?(_), do: false

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session(:aqua_sense)
    |> put_flash(:info, "You are now signed out")
    |> redirect(to: return_to)
  end
end
