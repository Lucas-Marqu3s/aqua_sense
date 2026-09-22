defmodule AquaSenseWeb.SignInLive do
  @moduledoc """
  Entrada do sistema: login e solicitação de cadastro.

  As duas telas dividem a mesma composição — painel de apresentação à
  esquerda, formulário à direita — e se separam por `@live_action`, que o
  `sign_in_route/1` do AshAuthentication define a partir da rota.

  Os formulários são POST comum para as rotas de `/auth`, não formulários de
  LiveView: quem valida credencial e devolve o flash é o AshAuthentication.
  """
  use AquaSenseWeb, :live_view

  on_mount {AquaSenseWeb.LiveUserAuth, :live_no_user}

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
