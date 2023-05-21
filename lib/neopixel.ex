defmodule Neopixel do

  import Neopixel.Guards

  @server Neopixel.Server

  alias Neopixel.Server

  def start_server(args) do
    Server.start_link(args)
  end

  def set_pixel(strip, pixel, "#" <> hexcolor) when is_strip(strip) do
    GenServer.call(@server, {:set_pixel, strip, pixel, hexcolor})
  end

  def set_pixel(strip, pixel, {r, g, b} = _color) when is_strip(strip) and is_rgb(r, g, b) do
    hexcolor = Base.encode16(<<0, r, g, b>>)
    GenServer.call(@server, {:set_pixel, strip, pixel, hexcolor})
  end

  def set_pixel(strip, pixel, {w, r, g, b} = _color)
      when is_strip(strip) and is_wrgb(w, r, g, b) do
    hexcolor = Base.encode16(<<w, r, g, b>>)
    GenServer.call(@server, {:set_pixel, strip, pixel, hexcolor})
  end

  def fill_strip(strip, "#" <> hexcolor) when is_strip(strip) do
    GenServer.call(@server, {:fill_strip, strip, hexcolor})
  end

  def fill_strip(strip, {r, g, b} = _color) when is_strip(strip) and is_rgb(r, g, b) do
    hexcolor = Base.encode16(<<0, r, g, b>>)
    GenServer.call(@server, {:fill_strip, strip, hexcolor})
  end

  def fill_strip(strip, {w, r, g, b} = _color) when is_strip(strip) and is_wrgb(w, r, g, b) do
    hexcolor = Base.encode16(<<w, r, g, b>>)
    GenServer.call(@server, {:fill_strip, strip, hexcolor})
  end

  def fill_rainbow(strip, hue_offset) when is_strip(strip) and is_255(hue_offset) do
    GenServer.call(@server, {:fill_rainbow, strip, hue_offset})
  end

  def fill_hue(strip, "#" <> hsvcolor) when is_strip(strip) do
    GenServer.call(@server, {:fill_hue, strip, hsvcolor})
  end

  def fill_hue(strip, hue_offset) when is_strip(strip) and is_255(hue_offset) do
    hsvcolor = Base.encode16(<<0, hue_offset, 0xFF, 0xFF>>)
    GenServer.call(@server, {:fill_hue, strip, hsvcolor})
  end

  def set_brightness(strip, brightness) when is_strip(strip) and is_255(brightness) do
    GenServer.call(@server, {:set_brightness, strip, brightness})
  end

  def hsv_to_rgb("#" <> hexcolor) do
    GenServer.call(@server, {:hsvrgb, hexcolor})
  end

  def render() do
    GenServer.call(@server, :render)
  end
end
