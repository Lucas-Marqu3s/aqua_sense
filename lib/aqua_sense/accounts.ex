defmodule AquaSense.Accounts do
  use Ash.Domain, otp_app: :aqua_sense, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource AquaSense.Accounts.Token
    resource AquaSense.Accounts.User
  end
end
