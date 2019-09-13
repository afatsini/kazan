defmodule Kazan.Client.ProtoDecoder do
  @moduledoc """
  Protocol Buffers decoder
  """
  alias Kazan.Codegen.Naming

  require Logger

  def decode(data, encoder) do
    [_kind, _apiVersion | value] = String.split(data, <<0>>)

    encoded = Enum.join(value, <<0>>)
    decoded = encoder.decode(encoded)

    k8s_to_kazan(decoded)
  end


  def k8s_to_kazan([object | rest]) do
    [k8s_to_kazan(object)] ++ k8s_to_kazan(rest)
  end

  def k8s_to_kazan(%_{} = object) do
    response_model = Naming.k8s_name_to_module_name(object.__struct__) |> IO.inspect

    case Code.ensure_compiled?(response_model) do
      false -> Logger.warn("Unknown object: #{inspect object}")
        object
      true ->
        {:ok, response} = apply(response_model, :decode, [Map.from_struct(object)]) |> IO.inspect

        decoded_keys = Map.keys(object)

        Enum.reduce(decoded_keys, response, fn(key, acc) ->
          if key != :__struct__ do
            value = k8s_to_kazan(Map.get(object, key))
            Map.put(acc, key, value)
          else
            acc
          end
        end)
    end
  end

  def k8s_to_kazan(object) do
    Logger.warn("Unknown object: #{inspect object}")
    object
  end
end
