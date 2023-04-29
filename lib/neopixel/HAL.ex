defmodule Neopixel.Server do
  @moduledoc """
  # Options:
  * `:dma_channel` the dma channel the neopixel driver will use
  * `:strip0_pin` pin number running strip 0
  * `:strip1_pin` pin number running strip 1
  * `:strip0_length` number of leds on strip 0
  * `:strip1_length` number of leds on strip 1
  """

  import Neopixel.Guards

  use GenServer

  require Logger

  def set_pixel(strip, pixel, "#" <> hexcolor) when is_strip(strip) do
    GenServer.call(__MODULE__, {:set_pixel, strip, pixel, hexcolor})
  end

  def set_pixel(strip, pixel, {r, g, b} = _color) when is_strip(strip) and is_rgb(r, g, b) do
    hexcolor = Base.encode16(<<0, r, g, b>>)
    GenServer.call(__MODULE__, {:set_pixel, strip, pixel, hexcolor})
  end

  def set_pixel(strip, pixel, {w, r, g, b} = _color)
      when is_strip(strip) and is_wrgb(w, r, g, b) do
    hexcolor = Base.encode16(<<w, r, g, b>>)
    GenServer.call(__MODULE__, {:set_pixel, strip, pixel, hexcolor})
  end

  def fill_strip(strip, "#" <> hexcolor) when is_strip(strip) do
    GenServer.call(__MODULE__, {:fill_strip, strip, hexcolor})
  end

  def fill_strip(strip, {r, g, b} = _color) when is_strip(strip) and is_rgb(r, g, b) do
    hexcolor = Base.encode16(<<0, r, g, b>>)
    GenServer.call(__MODULE__, {:fill_strip, strip, hexcolor})
  end

  def fill_strip(strip, {w, r, g, b} = _color) when is_strip(strip) and is_wrgb(w, r, g, b) do
    hexcolor = Base.encode16(<<w, r, g, b>>)
    GenServer.call(__MODULE__, {:fill_strip, strip, hexcolor})
  end

  def fill_rainbow(strip, hue_offset) when is_strip(strip) and is_255(hue_offset) do
    GenServer.call(__MODULE__, {:fill_rainbow, strip, hue_offset})
  end

  def fill_hue(strip, "#" <> hsvcolor) when is_strip(strip) do
    GenServer.call(__MODULE__, {:fill_hue, strip, hsvcolor})
  end

  def fill_hue(strip, hue_offset) when is_strip(strip) and is_255(hue_offset) do
    hsvcolor = Base.encode16(<<0, hue_offset, 0xFF, 0xFF>>)
    GenServer.call(__MODULE__, {:fill_hue, strip, hsvcolor})
  end

  def set_brightness(strip, brightness) when is_strip(strip) and is_255(brightness) do
    GenServer.call(__MODULE__, {:set_brightness, strip, brightness})
  end

  def hsv_to_rgb("#" <> hexcolor) do
    GenServer.call(__MODULE__, {:hsvrgb, hexcolor})
  end

  def render() do
    GenServer.call(__MODULE__, :render)
  end

  # test function for sending commands calls directly to Neopixel
  @doc false
  def send(command) do
    GenServer.call(__MODULE__, {:send, command})
  end

  @doc false
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc false
  def init(args) do
    file = Application.app_dir(:neopixels, ["priv", "Neopixel"]) |> String.to_charlist()

    config = [
      "#{args[:dma_channel] || 10}",
      "#{Keyword.fetch!(args, :strip0_pin)}",
      "#{Keyword.fetch!(args, :strip0_length)}",
      "#{Keyword.fetch!(args, :strip1_pin)}",
      "#{Keyword.fetch!(args, :strip1_length)}"
    ]

    port = connect_to_port(file, config)

    state = %{
      file: file,
      config: config,
      port: port
    }

    send(self(), :init_strips)
    {:ok, state}
  end

  def handle_call({:set_pixel, strip, pixel, color}, _from, state) when is_integer(pixel) do
    {:reply, send_to_port("set_pixel #{strip} #{pixel} 0x#{color}", state.port), state}
  end

  def handle_call({:set_pixel, strip, first_pixel..last_pixel, color}, _from, state) do
    {:reply,
     Enum.reduce((first_pixel - 1)..last_pixel, fn p, _acc ->
       send_to_port("set_pixel #{strip} #{p} 0x#{color}", state.port)
     end), state}
  end

  def handle_call({:fill_strip, strip, color}, _from, state) do
    {:reply, send_to_port("fill_strip #{strip} 0x#{color}", state.port), state}
  end

  def handle_call({:fill_rainbow, strip, hue_offset}, _from, state) do
    {:reply, send_to_port("fill_rainbow #{strip} #{hue_offset}", state.port), state}
  end

  def handle_call({:fill_hue, strip, hsvcolor}, _from, state) do
    {:reply, send_to_port("fill_hue #{strip} 0x#{hsvcolor}", state.port), state}
  end

  def handle_call({:set_brightness, strip, brightness}, _from, state) do
    {:reply, send_to_port("set_brightness #{strip} #{brightness}", state.port), state}
  end

  def handle_call({:hsvNeopixel, hsvcolor}, _from, state) do
    {:reply, send_to_port("hsvNeopixel 0x#{hsvcolor}", state.port), state}
  end

  def handle_call(:render, _from, state) do
    {:reply, send_to_port("render", state.port), state}
  end

  def handle_call({:send, command}, _from, state) do
    {:reply, send_to_port(command, state.port), state}
  end

  def handle_info(:init_strips, state) do
    :ok = send_to_port("fill_strip 0 0x00000000", state.port)
    :ok = send_to_port("fill_strip 0 0x00000000", state.port)
    :ok = send_to_port("render", state.port)
    {:noreply, state}
  end

  def handle_info({_port, {:data, {_, 'OK'}}}, state) do
    Logger.info("Neopixel: OK")
    {:noreply, state}
  end

  def handle_info({_port, {:data, {_, 'OK: ' ++ payload}}}, state) do
    Logger.info("Neopixel: #{payload}")
    {:noreply, state}
  end

  def handle_info({_port, {:data, {_, 'DBG: ' ++ payload}}}, state) do
    Logger.debug("Neopixel: #{payload}")
    {:noreply, state}
  end

  def handle_info({_port, {:data, {_, 'ERR: ' ++ payload}}}, state) do
    Logger.error("Neopixel: #{payload}")
    {:noreply, state}
  end

  def handle_info({_port, {:data, {_, _payload}}}, state) do
    {:noreply, state}
  end

  def handle_info({_port, {:exit_status, status}}, state) do
    Logger.error("Neopixel: died with exit_status: #{status}")
    {:noreply, state}
  end

  defp connect_to_port(file, args) do

    Port.open({:spawn_executable, file}, [
      {:args, args},
      {:line, 1024},
      :use_stdio,
      :stderr_to_stdout,
      :exit_status
    ])
  end

  defp send_to_port(command, port) do
    Logger.debug("Neopixel: sending command \"#{command}\"")
    Port.command(port, command <> "\n")
    recieve_from_port(port)
  end

  defp recieve_from_port(port) do
    receive do
      {^port, {:data, {_, 'OK'}}} ->
        :ok

      {^port, {:data, {_, 'OK: ' ++ payload}}} ->
        {:ok, to_string(payload)}

      {^port, {:data, {_, 'ERR: ' ++ payload}}} ->
        {:error, to_string(payload)}

      {^port, {:exit_status, status}} ->
        Logger.error("Neopixel has died with exit_status: #{status}")
        raise "Neopixel has died with exit_status: #{status}"
    after
      500 -> {:error, "timeout waiting for Neopixel to reply"}
    end
  end
end
