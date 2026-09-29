defmodule AquaSense.Monitoring do
  use Ash.Domain, otp_app: :aqua_sense, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource AquaSense.Monitoring.Reading
  end
end
