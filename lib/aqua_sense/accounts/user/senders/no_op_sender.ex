defmodule AquaSense.Accounts.User.Senders.NoOpSender do
  use AshAuthentication.Sender

  @impl true
  def send(_user, _token, _opts), do: :ok
end
