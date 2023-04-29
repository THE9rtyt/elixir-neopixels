defmodule Circuits.Neopixels.Application do
  @moduledoc false
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications

  use Application

  @impl true
  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [
      strategy: :one_for_one,
      name: Circuits.Neopixels.Supervisor
    ]

    children =
      [
        {Circuits.Neopixels.HAL, 1}
      ]

    Supervisor.start_link(children, opts)
  end
end
